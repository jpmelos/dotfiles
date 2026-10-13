# Task that downloads the bank statements and syncs new transactions to YNAB.
#
# Run it with `/run budget-sync` from the allowlisted chat. Optional words
# after the name are `--from-date YYYY-MM-DD`, `--no-download`, and
# `--no-upload`, with the same meaning as in `bin/budget_imports`.
#
# BMO comes from `agent-browser` downloads. Wise comes from the Wise API with
# the token in `wise.api_key`, without a browser. The Wise cache lives in
# the task state directory as JSON, so `--no-download` reuses the last Wise
# fetch, same as it reuses the last BMO statements.
#
# Every bank entry needs a decision in `transactions.json` in the task state:
# its YNAB payee, or its split parts with payee, amount, and memo each. The
# task asks in date order and remembers. One decision covers every identical
# entry of one day. YNAB gains missing copies and loses surplus copies of
# bank entries after one confirmation. Deletion happens only there. The chat
# only gets the new transactions, one short line each, plus short
# confirmations, balance lines, and a count of the transactions without a
# memo.

DESCRIPTION = "Sync new BMO and Wise transactions to YNAB."
# Banking with user questions can take a while. This is the budget for one
# run, in seconds.
TIMEOUT = 7200

# Requirement strings that the bot installs with `uv` into the venv of the
# task on every run.
DEPENDENCIES = ("ynab>=4.4.0,<5", "urllib3>=2,<3")

import collections
import contextlib
import csv
import datetime
import decimal
import enum
import io
import json
import os
import re
import shlex
import subprocess
import tempfile
import time
import urllib.parse
import uuid
from dataclasses import dataclass

import urllib3
import ynab

LOGIN_URL = "https://www1.bmo.com/banking/digital/"
# The `agent-browser` session of this task. A session of its own keeps the
# task from sharing a browser with other uses of `agent-browser`.
BROWSER_SESSION = "budget-sync"
# How long to wait for a page to load, and for a download to finish.
PAGE_WAIT_SECONDS = 5
DOWNLOAD_WAIT_SECONDS = 10
# How many days back the task looks. The chequing download covers these
# days, and the task ignores the transactions before them, in the statements
# and in YNAB.
HISTORY_DAYS = 30
# The first date of the transactions to process, without `--from-date`.
DEFAULT_FROM_DATE = datetime.date(2026, 10, 1)
# The format of the date that `--from-date` takes.
OPTION_DATE_FORMAT = "%Y-%m-%d"
# The forms take dates as MM/DD/YYYY.
FORM_DATE_FORMAT = "%m/%d/%Y"
# The bank gives this name to every statement that it sends.
DOWNLOAD_NAME = "statement.csv"
CSV_FORMAT = "Spreadsheet (CSV format)"
COOKIE_BUTTON = 'button[id="onetrust-accept-btn-handler"]'
# In the accessibility tree of the page of an account, the current balance is
# the first text with a dollar sign after the text `Current balance`.
CURRENT_BALANCE_PATTERN = re.compile(
    r'StaticText "Current balance".*?StaticText "(?P<balance>[^"]*\$[^"]*)"',
    re.DOTALL,
)
SMS_OPTION_NAME = "SMS text ••• - ••• -"
VERIFICATION_CONSENT_NAME = (
    "IMPORTANT: This code grants access to your accounts. It should always be "
    "kept private. To proceed, you must confirm you will not provide this "
    "verification code to anyone."
)
# State identifiers. Every file lives in the task state directory.
TRANSACTIONS_ID = "transactions.json"
CHEQUING_ID = "chequing.csv"
CREDIT_CARD_ID = "credit_card.csv"
WISE_ID = "wise.json"
DOWNLOAD_ID = "statement.csv"
SESSION_ID = "bmo_session.json"
TOKEN_ID = "questrade_refresh_token.txt"
SCREENSHOT_ID = "browser-error.png"
# When the last run finished, as an ISO timestamp. Other tasks read it to
# check whether this task ran today.
LAST_RUN_ID = "last_run.json"
# How many new transactions the chat report lists before it summarizes.
REPORT_LINE_LIMIT = 60


# --------------------------------------------------------------------------------------
# Task entry points.
# --------------------------------------------------------------------------------------

# The context of the current run. Set by `run`, read by the helpers below.
_CTX = None
# Whether this run opened the browser. Set by `Browser.open`, read by
# `shutdown` so the session is saved before the browser closes, even when the
# run is cancelled after the browser opened.
_BROWSER_OPENED = False


class TaskError(Exception):
    pass


def run(ctx, args=None):
    """Download the statements, record the decisions, and sync YNAB. Returns
    a short summary for the chat."""
    global _CTX
    _CTX = ctx
    from_date, no_download, no_upload = parse_task_args(list(args or []))
    ctx.say("Budget sync started.")
    try:
        ynab_api_key = read_config_text("ynab.api_key")
    except TaskError as error:
        _say(f"Cannot start: {error}")
        raise TaskError("YNAB API key is missing.") from error
    paths = resolve_state_files(ctx)
    if no_download:
        use_last_statements(paths)
        balances = None
        questrade_balance = None
    else:
        ctx.log(f"Reading the Questrade balances in {QUESTRADE_CURRENCY}")
        questrade_balances = read_questrade_balances(paths.questrade_token_file)
        questrade_balance = sum(questrade_balances.values())
        ctx.log(f"Questrade total {format_amount(questrade_balance)}")
        _say(f"Got Questrade balance {format_amount(questrade_balance)}.")
        wise_balance = run_wise_download(ctx, paths)
        balances = run_download(ctx, paths)
        balances[Account.WISE] = wise_balance

    # The task works only on the transactions from this date on, in the
    # statements and in YNAB.
    start_date = max(
        from_date, datetime.date.today() - datetime.timedelta(days=HISTORY_DAYS)
    )

    ctx.log("Reading the statements")
    statement_transactions = [
        *read_statement(paths.chequing_file, CHEQUING_STATEMENT),
        *read_statement(paths.credit_card_file, CREDIT_CARD_STATEMENT),
        *read_wise_transactions(paths.wise_file),
    ]
    transactions = [
        transaction
        for transaction in statement_transactions
        if transaction.date >= start_date
    ]
    ignored_count = len(statement_transactions) - len(transactions)
    ctx.log(f"Ignored transactions before {start_date.isoformat()}: {ignored_count}")
    _say(f"Read {len(statement_transactions)} transactions from the statements.")

    ctx.log("Recording the decisions")
    decisions = load_decisions(ctx)
    transactions = apply_decisions(ctx, transactions, decisions)
    ctx.log(f"Decided transactions: {len(transactions)} after expansion")

    matched, added_count, cleared_count, deleted_count, memo_count = save_to_ynab(
        ctx,
        transactions,
        decisions,
        start_date,
        balances,
        questrade_balance,
        ynab_api_key,
        upload=not no_upload,
    )
    if not matched:
        summary = "Done, preview only. YNAB unchanged."
    else:
        summary = (
            f"Done: {added_count} added, {cleared_count} cleared, "
            f"{deleted_count} deleted, {memo_count} memos updated."
        )
    record_last_run(ctx)
    _say(summary)
    return summary


def shutdown(ctx, reason):
    # Saves the browser session and closes the browser that a run leaves
    # open, whatever the outcome. The save runs first so a cancellation
    # after the browser opened keeps the login session. Never raises, so the
    # shutdown itself cannot fail the task.
    ctx.log(f"shutdown: {reason}")
    try:
        os.environ["AGENT_BROWSER_SESSION"] = BROWSER_SESSION
    except Exception as error:
        ctx.log(f"browser session setup failed: {error}")
        return
    if _BROWSER_OPENED:
        try:
            session_file = ctx.state_path(SESSION_ID)
        except Exception as error:
            ctx.log(f"browser session save skipped: {error}")
            session_file = None
        if session_file:
            try:
                parent = os.path.dirname(session_file)
                if parent:
                    os.makedirs(parent, mode=0o700, exist_ok=True)
                subprocess.run(
                    ["agent-browser", "state", "save", session_file],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    timeout=30,
                )
                try:
                    os.chmod(session_file, 0o600)
                except OSError as error:
                    ctx.log(f"browser session chmod failed: {error}")
            except Exception as error:
                ctx.log(f"browser session save failed: {error}")
    try:
        subprocess.run(
            ["agent-browser", "close"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=30,
        )
    except Exception as error:
        ctx.log(f"browser close failed: {error}")


def parse_task_args(args):
    # Returns the from date, no-download, and no-upload from `args`, the
    # words after the task name.
    from_date = DEFAULT_FROM_DATE
    no_download = False
    no_upload = False
    index = 0
    while index < len(args):
        argument = args[index]
        if argument == "--from-date":
            index += 1
            if index >= len(args):
                raise TaskError("Usage: /run budget-sync [--from-date YYYY-MM-DD]")
            try:
                from_date = datetime.datetime.strptime(
                    args[index], OPTION_DATE_FORMAT
                ).date()
            except ValueError:
                raise TaskError(
                    f"Invalid --from-date {args[index]!r}, expected YYYY-MM-DD"
                ) from None
        elif argument == "--no-download":
            no_download = True
        elif argument == "--no-upload":
            no_upload = True
        else:
            raise TaskError(
                "Usage: /run budget-sync [--from-date YYYY-MM-DD] "
                "[--no-download] [--no-upload]"
            )
        index += 1
    return from_date, no_download, no_upload


# --------------------------------------------------------------------------------------
# Chat helpers.
# --------------------------------------------------------------------------------------


def _say(text):
    _CTX.say(text)


def _log(text):
    _CTX.log(text)


def ask_code():
    # Asks for the SMS verification code of the bank. The reply never reaches
    # the log. A timeout stops the task through the bot.
    return _CTX.ask(
        "BMO sent an SMS code. Reply with the digits.", pattern=r"\d+", timeout=300
    )


def ask_yes(question, timeout=300):
    # Asks a yes or no question. Returns True for yes.
    answer = _CTX.ask(
        question + " Reply y or n.",
        pattern=r"(?i:yes|y|no|n)",
        timeout=timeout,
    )
    return answer.casefold() in ("y", "yes")


# --------------------------------------------------------------------------------------
# Configuration.
# --------------------------------------------------------------------------------------


def read_config_text(path):
    # Returns the text at `path` in the configuration. Raises when `jc get`
    # fails, or when the value is missing, `null`, empty, or not text.
    try:
        result = subprocess.run(
            ["jc", "get", path],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            encoding="utf-8",
            errors="replace",
            timeout=15,
        )
    except OSError as error:
        raise TaskError(f"cannot run jc: {error}") from error
    if result.returncode != 0:
        detail = (result.stderr or "").strip() or "no error message from jc"
        raise TaskError(f"cannot read ~/config.json: {detail}")

    try:
        value = json.loads(result.stdout)
    except ValueError as error:
        raise TaskError(f"jc returned invalid JSON for {path}: {error}") from error
    if value is None or value == "":
        raise TaskError(f"{path} not found in ~/config.json")
    if not isinstance(value, str):
        raise TaskError(f"{path} in ~/config.json is not text")
    return value


# --------------------------------------------------------------------------------------
# State files.
# --------------------------------------------------------------------------------------


@dataclass
class SessionPaths:
    # Every path sits in the task state directory. The statements, the Wise
    # cache, the bank session, the Questrade token, the payee map, and the
    # error screenshot all persist there across runs.
    session_dir: str
    session_file: str
    chequing_file: str
    credit_card_file: str
    wise_file: str
    # Where the browser saves each statement that the bank sends.
    download_file: str
    screenshot_file: str
    # The refresh token for the Questrade API that the last run saved.
    questrade_token_file: str


def resolve_state_files(ctx):
    session_dir = os.path.dirname(ctx.state_path(DOWNLOAD_ID))
    try:
        os.makedirs(session_dir, mode=0o700, exist_ok=True)
    except OSError as error:
        raise TaskError(f"cannot prepare the state directory: {error}") from error
    return SessionPaths(
        session_dir=session_dir,
        session_file=ctx.state_path(SESSION_ID),
        chequing_file=ctx.state_path(CHEQUING_ID),
        credit_card_file=ctx.state_path(CREDIT_CARD_ID),
        wise_file=ctx.state_path(WISE_ID),
        download_file=ctx.state_path(DOWNLOAD_ID),
        screenshot_file=ctx.state_path(SCREENSHOT_ID),
        questrade_token_file=ctx.state_path(TOKEN_ID),
    )


def record_last_run(ctx):
    # Stores when this run finished, so other tasks can check whether this
    # task ran today. A failure to store only warns, so it never fails a
    # run that already synced.
    stamp = datetime.datetime.now(datetime.UTC).isoformat()
    try:
        ctx.save_state(LAST_RUN_ID, {"last_run": stamp})
    except Exception as error:
        ctx.log(f"Warning: cannot save {LAST_RUN_ID}: {error}")


# --------------------------------------------------------------------------------------
# Steps.
# --------------------------------------------------------------------------------------


def run_download(ctx, paths):
    # Downloads the statements from the bank, and returns the balances that
    # `download_statements` returns.
    try:
        username = read_config_text("bmo.username")
        password = read_config_text("bmo.password")
    except TaskError as error:
        _say(f"Cannot log in: {error}")
        raise TaskError("BMO credentials are missing.") from error

    os.environ["AGENT_BROWSER_SESSION"] = BROWSER_SESSION
    browser = Browser()
    try:
        balances = download_statements(browser, paths, username, password)
    except StepError as error:
        # Before the browser opens, there is no page to show.
        if browser.opened:
            take_error_screenshot(ctx, browser, paths.screenshot_file)
        raise TaskError(str(error)) from error

    ctx.log("Statements downloaded")
    _say("Statements downloaded.")
    return balances


def use_last_statements(paths):
    _log("Using the statements of the last run")
    _say("Using the statements of the last run.")
    for statement_path in (
        paths.chequing_file,
        paths.credit_card_file,
        paths.wise_file,
    ):
        if not os.path.isfile(statement_path):
            raise TaskError("No downloaded statements. Run without --no-download first")


def download_statements(browser, paths, username, password):
    # Returns the current balance of each account. See `read_balance`.
    open_login_page(browser, paths)
    accept_cookies(browser)
    log_in(browser, username, password)
    pass_verification(browser)
    chequing_balance = download_chequing_statement(browser, paths)
    credit_card_balance = download_credit_card_statement(browser, paths)
    save_session(browser, paths)
    return {
        Account.CHEQUING: chequing_balance,
        Account.CREDIT_CARD: credit_card_balance,
    }


def open_login_page(browser, paths):
    _log("Opening the login page")
    # Close the browser that an earlier run left open, so that `open` launches
    # a new browser with the download path.
    browser.run("close", stdout=subprocess.DEVNULL)
    time.sleep(1)

    open_options = ["--download-path", paths.session_dir]
    # Before the first successful run, there is no session file.
    if os.path.isfile(paths.session_file):
        open_options += ["--state", paths.session_file]
    browser.open(LOGIN_URL, open_options)
    time.sleep(PAGE_WAIT_SECONDS)
    _say("Opened the browser in the BMO login page.")


def accept_cookies(browser):
    _log("Accepting cookies")
    output = browser.run("get", "count", COOKIE_BUTTON, stdout=subprocess.PIPE)
    try:
        count = int(output)
    except ValueError:
        raise StepError(
            f"`agent-browser get count` printed {output.strip()!r}, expected a number"
        ) from None
    if count > 0:
        browser.run("click", COOKIE_BUTTON)
    time.sleep(PAGE_WAIT_SECONDS)
    _say("Accepted cookies.")


def log_in(browser, username, password):
    _log("Logging in")
    browser.run("fill", 'input[id^="username-input"]', Secret(username))
    browser.run("fill", 'input[id^="password-input"]', Secret(password))
    browser.find_role("button", "click", "SIGN IN")
    time.sleep(PAGE_WAIT_SECONDS)
    _say("Logged in successfully.")


def pass_verification(browser):
    _log("Checking for 2FA")
    if browser.succeeds("find", "role", "radio", "text", "--name", "SMS text"):
        browser.find_role("radio", "click", SMS_OPTION_NAME)
        browser.find_role("checkbox", "click", VERIFICATION_CONSENT_NAME)
        browser.find_role("button", "click", "SEND CODE")
        time.sleep(PAGE_WAIT_SECONDS)

        sms_code = ask_code()
        browser.find_role(
            "spinbutton", "fill", "Enter verification code", Secret(sms_code)
        )
        browser.find_role("button", "click", "CONFIRM")
        time.sleep(PAGE_WAIT_SECONDS)
        _say("Passed verification.")
    else:
        _say("No verification needed.")

    time.sleep(PAGE_WAIT_SECONDS)


def download_chequing_statement(browser, paths):
    # Returns the current balance of the account. See `read_balance`.
    _log("Selecting the chequing account")
    browser.find_role("link", "click", "Chequing")
    time.sleep(PAGE_WAIT_SECONDS)
    balance = read_balance(browser, CHEQUING_STATEMENT)
    _say("Opened chequing account.")

    _log("Downloading the chequing account transactions")
    browser.find_role("link", "click", "DOWNLOAD")
    browser.find_role("radio", "click", "Transactions between these dates:")
    to_date = datetime.date.today()
    from_date = to_date - datetime.timedelta(days=HISTORY_DAYS)
    browser.find_role("textbox", "fill", "From", from_date.strftime(FORM_DATE_FORMAT))
    browser.find_role("textbox", "fill", "To", to_date.strftime(FORM_DATE_FORMAT))
    browser.run("select", 'select[name="format"]', CSV_FORMAT)
    browser.run("click", "#ba-tx-download-submit")
    time.sleep(DOWNLOAD_WAIT_SECONDS)

    browser.find_role("link", "click", "EXIT")
    save_statement(paths.download_file, paths.chequing_file)
    _say("Chequing statement downloaded successfully.")
    return balance


def download_credit_card_statement(browser, paths):
    # Returns the current balance of the account. See `read_balance`.
    _log("Selecting the credit card")
    browser.find_role("link", "click", "MasterCard")
    time.sleep(PAGE_WAIT_SECONDS)
    balance = read_balance(browser, CREDIT_CARD_STATEMENT)
    _say("Opened credit card.")

    _log("Downloading the credit card transactions")
    browser.find_role("link", "click", "DOWNLOAD")
    browser.run("select", 'select[name="period"]', "All Available Transactions")
    browser.run("select", 'select[name="format"]', CSV_FORMAT)
    browser.find_role("button", "click", "DOWNLOAD")
    time.sleep(DOWNLOAD_WAIT_SECONDS)

    save_statement(paths.download_file, paths.credit_card_file)
    _say("Credit card statement downloaded successfully.")
    return balance


def read_balance(browser, statement_format):
    # Returns the current balance on the page of the account of
    # `statement_format`, with the signs of `Transaction.amount`. Returns
    # `None` when the page shows no balance that the task can read. The
    # statements do not need the balance, so that case only logs.
    snapshot = browser.run("snapshot", stdout=subprocess.PIPE)
    match = CURRENT_BALANCE_PATTERN.search(snapshot)
    balance = None if match is None else parse_balance(match["balance"])
    if balance is None:
        account_label = ACCOUNT_LABELS[statement_format.account]
        _log(f"Warning: cannot read the current balance of the {account_label} page")
        _say(f"Cannot read the current balance of the {account_label} page.")
        return None
    return -balance if statement_format.inverted_amounts else balance


def parse_balance(text):
    # Returns the amount in `text`, such as `$6,494.68` or `- $12.00`, or
    # `None` when `text` holds no amount.
    try:
        balance = decimal.Decimal(re.sub(r"[\s$,]", "", text))
    except decimal.InvalidOperation:
        return None
    return balance if balance.is_finite() else None


def save_session(browser, paths):
    _log("Saving the state")
    browser.run("state", "save", paths.session_file)
    try:
        os.chmod(paths.session_file, 0o600)
    except OSError as error:
        raise StepError(f"cannot set the mode of the session file: {error}") from error
    _say("Saved the session.")


def save_statement(download_path, statement_path):
    # Moves the statement at `download_path` to `statement_path`. Every
    # statement arrives under the same name, so each one must move before the
    # next download. Removes the download afterwards, so no transient file
    # stays in the state.
    #
    # Before the header row, the bank adds a line with the time of the export.
    # It also adds empty lines around the header row. Keep only the header
    # row, which is the first line with a comma, and the rows of the table.
    # The lines stay bytes, so the encoding of the bank does not matter.
    try:
        with open(download_path, "rb") as download:
            lines = download.readlines()
    except FileNotFoundError:
        raise StepError(
            "The download is missing. The download failed, or took more "
            f"than {DOWNLOAD_WAIT_SECONDS} seconds"
        ) from None
    except OSError as error:
        raise StepError(f"cannot read the download: {error}") from error

    header_found = False
    kept_lines = []
    for line in lines:
        if b"," in line:
            header_found = True
        if header_found and line.strip():
            kept_lines.append(line if line.endswith(b"\n") else line + b"\n")

    try:
        with open(statement_path, "wb") as statement:
            statement.writelines(kept_lines)
        try:
            os.chmod(statement_path, 0o600)
        except OSError:
            pass
        os.remove(download_path)
    except OSError as error:
        raise StepError(f"cannot save the statement: {error}") from error


def take_error_screenshot(ctx, browser, screenshot_path):
    # The screenshot can show account data, so it stays in the private state
    # directory.
    try:
        browser.run(
            "screenshot",
            "--full",
            "--annotate",
            screenshot_path,
            stdout=subprocess.DEVNULL,
        )
    except StepError:
        ctx.log("Warning: failed to take a screenshot of the browser")
        return
    ctx.log("Screenshot of the browser saved to the state")


# --------------------------------------------------------------------------------------
# Transactions.
# --------------------------------------------------------------------------------------


class Account(enum.IntEnum):
    # The order of the values is the order of the accounts in the report.
    CHEQUING = 0
    CREDIT_CARD = 1
    WISE = 2


ACCOUNT_LABELS = {
    Account.CHEQUING: "Chequing",
    Account.CREDIT_CARD: "Credit card",
    Account.WISE: "Wise",
}

# Short account tags for the narrow chat report.
ACCOUNT_TAGS = {
    Account.CHEQUING: "Chq",
    Account.CREDIT_CARD: "MC",
    Account.WISE: "Wise",
}

# The source of each statement, for the keys of the transaction database.
# The account maps to exactly one source.
SOURCE_BY_ACCOUNT = {
    Account.CHEQUING: "bmo_chequing",
    Account.CREDIT_CARD: "bmo_credit_card",
    Account.WISE: "wise",
}
ACCOUNTS_BY_SOURCE = {name: account for account, name in SOURCE_BY_ACCOUNT.items()}


@dataclass
class Transaction:
    date: datetime.date
    # A negative amount is money that the user loses, and a positive amount is
    # money that the user makes.
    amount: decimal.Decimal
    # The payee for YNAB. At first it is the payee name of the bank. The
    # decision for the entry replaces it with the name of the user, or the
    # entry expands into split parts with their own payees.
    payee: str
    account: Account
    # The memo for YNAB. None means no memo. The chat asks for it before the
    # transaction goes to YNAB, unless a stored decision already holds it.
    memo: str = None
    # The payee name of the bank, as the statement gave it. The decision key
    # uses it, so it never changes.
    bank_payee: str = ""
    # Whether a stored decision already holds the memo. When False, the chat
    # asks for the memo before the transaction goes to YNAB.
    memo_ready: bool = False


@dataclass(frozen=True)
class StatementFormat:
    account: Account
    # The names of the columns, without the spaces around them. The column
    # that the bank calls `Description` holds the payee name.
    date_column: str
    amount_column: str = "Transaction Amount"
    payee_column: str = "Description"
    # Whether the statement shows money that the user loses as a positive
    # amount, which is the opposite of `Transaction.amount`.
    inverted_amounts: bool = False


CHEQUING_STATEMENT = StatementFormat(Account.CHEQUING, date_column="Date Posted")
CREDIT_CARD_STATEMENT = StatementFormat(
    Account.CREDIT_CARD, date_column="Transaction Date", inverted_amounts=True
)
# The statements give dates as YYYYMMDD.
STATEMENT_DATE_FORMAT = "%Y%m%d"


def read_statement(path, statement_format):
    # Returns the transactions in the statement at `path`. The names in the
    # header row and the values can have spaces around them, such as the
    # padding after a payee name, so the spaces go away.
    reader = csv.reader(io.StringIO(read_statement_text(path)))
    header = next(reader, None)
    if header is None:
        _log("Warning: a statement is empty, no transactions read")
        _say("A statement is empty, no transactions read.")
        return []

    columns = [name.strip() for name in header]
    date_index = find_column(columns, statement_format.date_column)
    amount_index = find_column(columns, statement_format.amount_column)
    payee_index = find_column(columns, statement_format.payee_column)

    transactions = []
    for row in reader:
        if not any(cell.strip() for cell in row):
            continue
        # A payee name with a comma and without quotes spreads over the cells
        # after it. When the payee name is the last column, those cells join
        # back into it.
        if len(row) > len(columns) and payee_index == len(columns) - 1:
            row = [*row[:payee_index], ",".join(row[payee_index:])]
        if len(row) != len(columns):
            raise TaskError(
                f"a statement row has {len(row)} values, expected {len(columns)}"
            )

        amount = parse_statement_amount(row[amount_index])
        if statement_format.inverted_amounts:
            amount = -amount
        bank_payee = row[payee_index].strip()
        transactions.append(
            Transaction(
                date=parse_statement_date(row[date_index]),
                amount=amount,
                payee=bank_payee,
                account=statement_format.account,
                bank_payee=bank_payee,
            )
        )
    return transactions


def read_statement_text(path):
    # The statements do not name their encoding. UTF-8 comes first, and
    # Windows-1252 covers the rest.
    try:
        with open(path, "rb") as handle:
            data = handle.read()
    except OSError as error:
        raise TaskError(f"cannot read a statement: {error}") from error
    try:
        return data.decode("utf-8-sig")
    except UnicodeDecodeError:
        return data.decode("cp1252", errors="replace")


def find_column(columns, name):
    # Returns the index of the column `name` in `columns`, the header row of
    # a statement.
    if name not in columns:
        raise TaskError(f"a statement has no '{name}' column")
    return columns.index(name)


def parse_statement_date(value):
    try:
        return datetime.datetime.strptime(value.strip(), STATEMENT_DATE_FORMAT).date()
    except ValueError:
        raise TaskError(f"invalid date {value.strip()!r} in a statement") from None


def parse_statement_amount(value):
    try:
        amount = decimal.Decimal(value.strip())
    except decimal.InvalidOperation:
        amount = None
    if amount is None or not amount.is_finite():
        raise TaskError(f"invalid amount {value.strip()!r} in a statement")
    return amount


# --------------------------------------------------------------------------------------
# Transaction decisions.
# --------------------------------------------------------------------------------------

# A decision row is a dict with a `key` of (source, date ISO, bank payee,
# bank amount), a `count` of bank entries with that key, and either kind
# `single` with a `payee` and a memo, or kind `split` with `parts` of payee,
# amount, and memo. A single without a `memo` entry still needs its memo
# from the chat. A part always holds its memo, None for none.


def load_decisions(ctx):
    # Returns the decision rows in `TRANSACTIONS_ID`, validated. A missing
    # file gives an empty list. Raises when a row holds bad data, so bad
    # data never reaches YNAB silently.
    raw = ctx.load_state(TRANSACTIONS_ID)
    if raw is None:
        return []
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as error:
        raise TaskError(f"cannot read {TRANSACTIONS_ID}: {error}") from error
    try:
        data = json.loads(text)
    except ValueError as error:
        raise TaskError(f"cannot read {TRANSACTIONS_ID}: {error}") from error
    if not isinstance(data, list):
        raise TaskError(f"{TRANSACTIONS_ID} holds no decision list")
    decisions = []
    seen_keys = set()
    for index, entry in enumerate(data):
        decision = parse_decision(entry, index)
        if decision["key"] in seen_keys:
            raise TaskError(f"{TRANSACTIONS_ID} row {index} repeats a key")
        seen_keys.add(decision["key"])
        decisions.append(decision)
    return decisions


def parse_decision(entry, index):
    # Returns the validated decision row for `entry`, the JSON object at
    # `index` in `TRANSACTIONS_ID`.
    what = f"{TRANSACTIONS_ID} row {index}"
    if not isinstance(entry, dict):
        raise TaskError(f"{what} holds no decision object")
    source = entry.get("source")
    if source not in ACCOUNTS_BY_SOURCE:
        raise TaskError(f"{what} has a bad source {source!r}")
    try:
        date = datetime.date.fromisoformat(entry.get("date", ""))
    except (TypeError, ValueError):
        raise TaskError(f"{what} has a bad date {entry.get('date')!r}") from None
    bank_payee = entry.get("bank_payee")
    if not isinstance(bank_payee, str) or bank_payee != bank_payee.strip():
        raise TaskError(f"{what} has a bad bank payee")
    if not bank_payee:
        raise TaskError(f"{what} has a bad bank payee")
    bank_amount = parse_decision_amount(entry.get("bank_amount"), f"{what} bank amount")
    count = entry.get("count")
    if isinstance(count, bool) or not isinstance(count, int) or count < 1:
        raise TaskError(f"{what} has a bad count")
    kind = entry.get("kind")
    key = (source, date.isoformat(), bank_payee, bank_amount)
    if kind == "single":
        payee = entry.get("payee")
        check_decision_payee(payee, f"{what} payee")
        memo_ready = "memo" in entry
        memo = entry.get("memo")
        if memo_ready and memo is not None and not isinstance(memo, str):
            raise TaskError(f"{what} has a bad memo")
        return {
            "key": key,
            "count": count,
            "kind": "single",
            "payee": payee,
            "memo": memo,
            "memo_ready": memo_ready,
        }
    if kind == "split":
        parts = parse_decision_parts(entry.get("parts"), what, bank_amount)
        return {"key": key, "count": count, "kind": "split", "parts": parts}
    raise TaskError(f"{what} has a bad kind {kind!r}")


def check_decision_payee(payee, what):
    # Raises when `payee` cannot go to YNAB as a name.
    if not isinstance(payee, str) or payee != payee.strip() or not payee:
        raise TaskError(f"bad {what}: {payee!r}")
    if len(payee) > YNAB_PAYEE_NAME_LIMIT:
        raise TaskError(f"bad {what}: over the YNAB payee limit")


def parse_decision_parts(raw_parts, what, bank_amount):
    # Returns the validated split parts in `raw_parts`. Raises when the parts
    # are fewer than two, hold bad values, or do not add to `bank_amount`.
    if not isinstance(raw_parts, list) or len(raw_parts) < 2:
        raise TaskError(f"{what} holds fewer than two parts")
    if bank_amount == 0:
        raise TaskError(f"{what} cannot split a zero amount")
    parts = []
    for part_index, raw_part in enumerate(raw_parts):
        part_what = f"{what} part {part_index + 1}"
        if not isinstance(raw_part, dict):
            raise TaskError(f"{part_what} holds no part object")
        payee = raw_part.get("payee")
        check_decision_payee(payee, f"{part_what} payee")
        amount = parse_decision_amount(raw_part.get("amount"), f"{part_what} amount")
        if amount == 0:
            raise TaskError(f"{part_what} amount is zero")
        if (amount > 0) != (bank_amount > 0):
            raise TaskError(f"{part_what} amount has the wrong sign")
        if "memo" not in raw_part:
            raise TaskError(f"{part_what} has no memo")
        memo = raw_part.get("memo")
        if memo is not None and not isinstance(memo, str):
            raise TaskError(f"{part_what} has a bad memo")
        parts.append({"payee": payee, "amount": amount, "memo": memo})
    if sum((part["amount"] for part in parts), decimal.Decimal("0")) != bank_amount:
        raise TaskError(f"{what} parts do not add to the bank amount")
    return parts


def parse_decision_amount(raw, what):
    # Returns the decimal value of `raw`, a JSON amount. Raises with `what`
    # in the message when the value is bad.
    if isinstance(raw, bool):
        raise TaskError(f"bad {what}: {raw!r}")
    if isinstance(raw, int):
        amount = decimal.Decimal(raw)
    elif isinstance(raw, float):
        amount = decimal.Decimal(str(raw))
    elif isinstance(raw, str):
        try:
            amount = decimal.Decimal(raw.strip())
        except decimal.InvalidOperation:
            raise TaskError(f"bad {what}: {raw!r}") from None
    else:
        raise TaskError(f"bad {what}: {raw!r}")
    if not amount.is_finite():
        raise TaskError(f"bad {what}: {raw!r}")
    return amount


def save_decisions(ctx, decisions):
    # Writes `decisions` to `TRANSACTIONS_ID` in canonical form, so amounts
    # keep their exact value and decided memos stay apart from unasked ones.
    data = []
    for decision in decisions:
        source, date_iso, bank_payee, bank_amount = decision["key"]
        entry = {
            "source": source,
            "date": date_iso,
            "bank_payee": bank_payee,
            "bank_amount": str(bank_amount),
            "count": decision["count"],
            "kind": decision["kind"],
        }
        if decision["kind"] == "single":
            entry["payee"] = decision["payee"]
            if decision["memo_ready"]:
                entry["memo"] = decision["memo"]
        else:
            entry["parts"] = [
                {
                    "payee": part["payee"],
                    "amount": str(part["amount"]),
                    "memo": part["memo"],
                }
                for part in decision["parts"]
            ]
        data.append(entry)
    try:
        ctx.save_state(TRANSACTIONS_ID, data)
    except (OSError, TypeError, ValueError) as error:
        raise TaskError(f"cannot save {TRANSACTIONS_ID}: {error}") from error


def transaction_decision_key(transaction):
    # Returns the database key of `transaction`: source, date, bank payee,
    # and bank amount.
    return (
        SOURCE_BY_ACCOUNT[transaction.account],
        transaction.date.isoformat(),
        transaction.bank_payee,
        transaction.amount,
    )


def apply_decisions(ctx, transactions, decisions):
    # Walks `transactions` in date order. A stored decision applies silently.
    # Any other group of identical entries asks whether to split, then asks
    # for the payee or the parts, and stores the new decision at once.
    # Returns the expanded list, with every split replaced by its parts.
    lookup = {decision["key"]: decision for decision in decisions}
    groups = {}
    for transaction in sorted(transactions, key=lambda item: (item.date, item.amount)):
        groups.setdefault(transaction_decision_key(transaction), []).append(transaction)
    remembered_count = 0
    new_count = 0
    dirty = False
    for key, members in groups.items():
        decision = lookup.get(key)
        if decision is None:
            decision = ask_decision(ctx, members)
            decision["count"] = len(members)
            decisions.append(decision)
            lookup[key] = decision
            save_decisions(ctx, decisions)
            new_count += 1
        elif decision["count"] != len(members):
            decision["count"] = len(members)
            dirty = True
        else:
            remembered_count += 1
    if dirty:
        save_decisions(ctx, decisions)
    expanded = []
    for key, members in groups.items():
        for member in members:
            expanded.extend(decision_transactions(lookup[key], member))
    ctx.log(f"decisions: {remembered_count} remembered, {new_count} new")
    _say(f"Decisions done, {new_count} new.")
    return expanded


def decision_transactions(decision, template):
    # Returns the YNAB-bound transactions for one bank entry with `decision`:
    # the entry itself with the stored payee for a single, or one entry per
    # part for a split. A split replaces its original.
    if decision["kind"] == "single":
        return [
            Transaction(
                date=template.date,
                amount=template.amount,
                payee=decision["payee"],
                account=template.account,
                bank_payee=template.bank_payee,
                memo=decision["memo"],
                memo_ready=decision["memo_ready"],
            )
        ]
    return [
        Transaction(
            date=template.date,
            amount=part["amount"],
            payee=part["payee"],
            account=template.account,
            bank_payee=template.bank_payee,
            memo=part["memo"],
            memo_ready=True,
        )
        for part in decision["parts"]
    ]


def ask_decision(ctx, members):
    # Asks how one group of identical bank entries splits, and returns the
    # new decision row. `members` holds the entries.
    representative = members[0]
    lines = [decision_line(representative)]
    if len(members) > 1:
        lines.append(f"Applies to {len(members)} identical entries.")
    if ask_yes("\n".join(lines) + "\nSplit this entry?"):
        return ask_split_decision(ctx, representative, len(members))
    payee = ask_single_payee(ctx, representative, len(members))
    return {
        "key": transaction_decision_key(representative),
        "count": len(members),
        "kind": "single",
        "payee": payee,
        "memo": None,
        "memo_ready": False,
    }


def decision_line(transaction):
    # One short line with the bank payee, for the decision questions.
    payee = transaction.bank_payee
    if len(payee) > 20:
        payee = payee[:19] + "…"
    return (
        f"{transaction.date.strftime('%m-%d')} "
        f"{ACCOUNT_TAGS[transaction.account]} "
        f"{format_amount(transaction.amount)} {payee}"
    )


def ask_single_payee(ctx, transaction, count):
    # Returns the YNAB payee for one undecided bank entry. Asks until the
    # reply holds a name within the YNAB limit.
    lines = ["New payee:", decision_line(transaction)]
    if count > 1:
        lines.append(f"Applies to {count} identical entries.")
    lines.append("Reply with the name to use.")
    while True:
        payee = ctx.ask("\n".join(lines), pattern=r"[\s\S]+", timeout=600).strip()
        if not payee:
            continue
        if len(payee) > YNAB_PAYEE_NAME_LIMIT:
            _say(f"That name is over the YNAB payee limit of {YNAB_PAYEE_NAME_LIMIT}.")
            continue
        return payee


def ask_split_decision(ctx, transaction, count):
    # Returns the split decision row for one group of identical bank entries.
    # Asks the part count, then the payee, amount, and memo of each part.
    # Restarts the entry when the parts do not add to the bank amount.
    if transaction.amount == 0:
        raise TaskError("cannot split a zero amount")
    key = transaction_decision_key(transaction)
    while True:
        part_count = ask_part_count(ctx)
        parts = [
            ask_split_part(ctx, transaction, part_number, part_count)
            for part_number in range(1, part_count + 1)
        ]
        total = sum((part["amount"] for part in parts), decimal.Decimal("0"))
        if total == transaction.amount:
            return {
                "key": key,
                "count": count,
                "kind": "split",
                "parts": parts,
            }
        _say(
            f"Parts add to {format_amount(total)}, "
            f"expected {format_amount(transaction.amount)}. Start over."
        )


def ask_part_count(ctx):
    # Returns how many parts a split holds. Asks until the reply holds a
    # number of at least two. There is no cap.
    while True:
        reply = ctx.ask(
            "Split into how many parts?\nReply with a number, at least 2.",
            pattern=r"\d+",
            timeout=300,
        ).strip()
        try:
            count = int(reply)
        except ValueError:
            continue
        if count >= 2:
            return count


def ask_split_part(ctx, transaction, part_number, part_count):
    # Returns one split part with its payee, amount, and memo. Restarts the
    # part when the payee or the amount cannot go to YNAB.
    label = f"Part {part_number} of {part_count} for {decision_line(transaction)}"
    while True:
        payee = ctx.ask(
            f"{label}\nReply with the payee.", pattern=r"[\s\S]+", timeout=600
        ).strip()
        if not payee:
            continue
        if len(payee) > YNAB_PAYEE_NAME_LIMIT:
            _say(f"That name is over the YNAB payee limit of {YNAB_PAYEE_NAME_LIMIT}.")
            continue
        break
    while True:
        reply = ctx.ask(
            f"{label}\n{payee}\nReply with the signed amount "
            "(negative for money lost).",
            pattern=r"[\s\S]+",
            timeout=300,
        )
        amount = parse_user_amount(reply)
        if amount is None:
            continue
        if amount == 0:
            _say("The amount cannot be zero.")
            continue
        if (amount > 0) != (transaction.amount > 0):
            _say("The amount has the wrong sign.")
            continue
        break
    memo = ask_memo(
        Transaction(
            date=transaction.date,
            amount=amount,
            payee=payee,
            account=transaction.account,
        )
    )
    return {"payee": payee, "amount": amount, "memo": memo}


def parse_user_amount(text):
    # Returns the decimal value of a typed amount such as `-1,005.00`, or
    # None when the text holds no amount.
    cleaned = text.strip().replace(",", "").replace("$", "").replace(" ", "")
    if not re.fullmatch(r"[+-]?\d+(\.\d+)?", cleaned):
        return None
    try:
        amount = decimal.Decimal(cleaned)
    except decimal.InvalidOperation:
        return None
    return amount if amount.is_finite() else None


# --------------------------------------------------------------------------------------
# Narrow chat report.
# --------------------------------------------------------------------------------------


def report_order(transaction):
    # By date, then by amount, then by payee, then by account. The payee
    # comparison ignores case, and the exact name breaks a tie.
    return (
        transaction.date,
        transaction.amount,
        transaction.payee.casefold(),
        transaction.payee,
        transaction.account,
    )


def format_amount(amount):
    # Returns the amount as $10,000.00, with the minus before the dollar
    # sign for negatives.
    sign = "-" if amount < 0 else ""
    return f"{sign}${abs(amount):,.2f}"


def format_details(date, amount, *texts):
    # Returns the date, the amount, and `texts` for the bot log.
    return "  ".join([date.isoformat(), format_amount(amount), *texts])


def compact_line(transaction):
    # One short line for a narrow screen: date, account tag, amount, payee.
    payee = transaction.payee
    if len(payee) > 20:
        payee = payee[:19] + "…"
    return (
        f"{transaction.date.strftime('%m-%d')} "
        f"{ACCOUNT_TAGS[transaction.account]} "
        f"{format_amount(transaction.amount)} {payee}"
    )


def say_new_transactions(transactions):
    # Reports only the transactions that YNAB does not have yet.
    if not transactions:
        _say("No new transactions.")
        return
    lines = [f"New ({len(transactions)}):"]
    for transaction in sorted(transactions, key=report_order)[:REPORT_LINE_LIMIT]:
        lines.append(compact_line(transaction))
    if len(transactions) > REPORT_LINE_LIMIT:
        lines.append(f"+{len(transactions) - REPORT_LINE_LIMIT} more")
    _say("\n".join(lines))


# --------------------------------------------------------------------------------------
# Questrade.
# --------------------------------------------------------------------------------------

QUESTRADE_TOKEN_URL = "https://login.questrade.com/oauth2/token"
# The token endpoint answers with one of these statuses when it rejects a
# refresh token, such as one that expired or that a run used already.
QUESTRADE_REJECTED_STATUSES = (400, 401)
# The combined balance of an account in this currency converts all the
# holdings of the account, in all currencies, to this currency.
QUESTRADE_CURRENCY = "CAD"
QUESTRADE_TIMEOUT_SECONDS = 30
CENT = decimal.Decimal("0.01")


@dataclass
class QuestradeSession:
    access_token: str
    # The URL of the API server that Questrade gave with the access token.
    api_server: str


def read_questrade_balances(token_path):
    # Returns the balance of each Questrade account in `QUESTRADE_CURRENCY`,
    # rounded to cents, by the type and the number of the account.
    session = start_questrade_session(token_path)
    accounts = questrade_get(session, "accounts", "read the Questrade accounts")
    accounts = accounts.get("accounts")
    if not isinstance(accounts, list) or not accounts:
        raise TaskError("Questrade returned no accounts")

    balances = {}
    for account in accounts:
        number = account.get("number") if isinstance(account, dict) else None
        # The number goes into the URL of the next call.
        if not isinstance(number, str) or not number.isdigit():
            raise TaskError(f"Questrade returned an account with the number {number!r}")
        account_balances = questrade_get(
            session,
            f"accounts/{number}/balances",
            f"read the balances of the Questrade account {number}",
        )
        label = f"{account.get('type')} {number}"
        balances[label] = find_combined_balance(account_balances, number)
    return balances


def find_combined_balance(account_balances, account_number):
    # Returns the total equity in `QUESTRADE_CURRENCY` from the combined
    # balances in `account_balances`, rounded to cents.
    records = account_balances.get("combinedBalances")
    if not isinstance(records, list):
        records = []
    for record in records:
        if not isinstance(record, dict):
            continue
        if record.get("currency") != QUESTRADE_CURRENCY:
            continue
        total_equity = record.get("totalEquity")
        # The JSON parser gives each number as an `int` or a `decimal.Decimal`.
        # `bool` is a subclass of `int`, so it needs a check of its own.
        if isinstance(total_equity, bool) or not isinstance(
            total_equity, (int, decimal.Decimal)
        ):
            raise TaskError(
                f"Questrade returned a bad total equity for account {account_number}"
            )
        return decimal.Decimal(total_equity).quantize(CENT)
    raise TaskError(
        f"Questrade returned no combined balance in {QUESTRADE_CURRENCY} for "
        f"account {account_number}"
    )


def start_questrade_session(token_path):
    # Returns a session with a new access token. Questrade accepts each
    # refresh token once, and returns a new one with the access token. The
    # new refresh token goes to `token_path` before any other call, so that
    # the next run can use it. The refresh token that `jc` reads serves only
    # when `token_path` holds no token, or when Questrade rejects that token.
    response = None
    saved_token = read_questrade_token(token_path)
    if saved_token is None:
        _log("No saved Questrade token. The task uses `jc get questrade.api_key`.")
    else:
        response = redeem_questrade_token(saved_token)
        if response is None:
            _log(
                "Warning: Questrade rejected the saved refresh token. The task "
                "uses `jc get questrade.api_key`."
            )
    if response is None:
        try:
            fallback = read_config_text("questrade.api_key")
        except TaskError as error:
            _say(f"Questrade needs a refresh token: {error}")
            raise TaskError("Questrade refresh token is missing.") from error
        response = redeem_questrade_token(fallback)
        if response is None:
            _say(
                "Questrade rejected both refresh tokens. Generate a new "
                "token in the Questrade API Centre and save it as "
                "questrade.api_key."
            )
            raise TaskError("Questrade rejected both refresh tokens.")

    refresh_token = response.get("refresh_token")
    if not isinstance(refresh_token, str) or not refresh_token:
        raise TaskError("Questrade returned no refresh token")
    save_questrade_token(token_path, refresh_token)

    access_token = response.get("access_token")
    if not isinstance(access_token, str) or not access_token:
        raise TaskError("Questrade returned no access token")
    # The access token goes to this server, so the connection must be secure.
    api_server = response.get("api_server")
    if not isinstance(api_server, str) or not api_server.startswith("https://"):
        raise TaskError("Questrade returned a bad API server")
    return QuestradeSession(access_token=access_token, api_server=api_server)


def read_questrade_token(path):
    # Returns the refresh token in the file at `path`, or `None` when the file
    # does not exist or holds no token.
    try:
        with open(path, encoding="utf-8") as handle:
            token = handle.read().strip()
    except FileNotFoundError:
        return None
    except (OSError, UnicodeDecodeError) as error:
        raise TaskError(f"cannot read the Questrade token: {error}") from error
    return token or None


def save_questrade_token(path, token):
    # The new file replaces the old one in one rename, so an interruption
    # cannot leave a partial token. `mkstemp` creates the file with mode
    # `600`, so only the user can read the token.
    try:
        descriptor, temp_path = tempfile.mkstemp(
            dir=os.path.dirname(path), prefix=".questrade-", suffix=".txt"
        )
    except OSError as error:
        raise TaskError(f"cannot save the Questrade token: {error}") from error

    replaced = False
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(token + "\n")
        os.replace(temp_path, path)
        replaced = True
    except OSError as error:
        raise TaskError(f"cannot save the Questrade token: {error}") from error
    finally:
        if not replaced:
            with contextlib.suppress(OSError):
                os.remove(temp_path)


def redeem_questrade_token(refresh_token):
    # Returns the JSON object that the token endpoint returns for
    # `refresh_token`, or `None` when the endpoint rejects the token. The
    # token goes in the body of the request, not in the URL, so that no error
    # message shows it.
    action = "redeem the Questrade refresh token"
    response = send_questrade_request(
        action,
        "POST",
        QUESTRADE_TOKEN_URL,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        body=urllib.parse.urlencode(
            {"grant_type": "refresh_token", "refresh_token": refresh_token}
        ),
    )
    if response.status in QUESTRADE_REJECTED_STATUSES:
        return None
    if response.status != 200:
        raise TaskError(f"cannot {action}: {describe_questrade_failure(response)}")
    return parse_questrade_response(action, response)


def questrade_get(session, path, action):
    # Returns the JSON object that the API server of `session` returns for
    # `path`, such as `accounts`. Raises with `action` in the message when the
    # call fails.
    response = send_questrade_request(
        action,
        "GET",
        questrade_url(session.api_server, path),
        headers={"Authorization": f"Bearer {session.access_token}"},
    )
    if response.status != 200:
        raise TaskError(f"cannot {action}: {describe_questrade_failure(response)}")
    return parse_questrade_response(action, response)


def questrade_url(api_server, path):
    # The URL of the API server usually ends in a slash, but the
    # documentation of Questrade also shows one that ends in `/v1`. Both
    # forms give the same URL.
    base_url = api_server.rstrip("/").removesuffix("/v1")
    return f"{base_url}/v1/{path}"


def send_questrade_request(action, method, url, **keyword_arguments):
    # Sends one request to Questrade, and returns the response. Raises with
    # `action` in the message when no response arrives.
    try:
        return urllib3.request(
            method, url, timeout=QUESTRADE_TIMEOUT_SECONDS, **keyword_arguments
        )
    except urllib3.exceptions.HTTPError as error:
        raise TaskError(f"cannot {action}: {error}") from error


def parse_questrade_response(action, response):
    # Returns the JSON object in the body of `response`. A number with a
    # fraction becomes a `decimal.Decimal`, so an amount keeps its exact
    # value.
    try:
        value = json.loads(response.data, parse_float=decimal.Decimal)
    except ValueError as error:
        raise TaskError(
            f"cannot {action}: Questrade returned invalid JSON: {error}"
        ) from error
    if not isinstance(value, dict):
        raise TaskError(f"cannot {action}: Questrade returned no JSON object")
    return value


def describe_questrade_failure(response):
    # Returns the HTTP status of `response`, with the message of the error
    # when the body holds one, such as `Access token is invalid`.
    description = f"HTTP {response.status}"
    try:
        body = json.loads(response.data)
    except ValueError:
        return description
    if isinstance(body, dict) and isinstance(body.get("message"), str):
        return f"{description}, {body['message']}"
    return description


# --------------------------------------------------------------------------------------
# Wise.
# --------------------------------------------------------------------------------------

# The base of the Wise Platform API. The balance calls use `/v4` and the
# profile and statement calls use `/v1`, as in the Wise docs.
WISE_API_BASE = "https://api.wise.com"
WISE_TIMEOUT_SECONDS = 30
# Only this currency syncs to YNAB. The YNAB account holds one currency, and
# Wise holds each currency in a balance of its own. Transactions and the
# balance come from the CAD STANDARD balance, the chequing account. SAVINGS
# balances, the jars, and other currencies stay out. That balance maps to the
# "Wise" account in YNAB. The profile and the balance come from
# `wise.profile_id` and `wise.balance_id` in the configuration, as strings.
WISE_CURRENCY = "CAD"


def run_wise_download(ctx, paths):
    # Fetches the Wise transactions and balance through the API, saves the
    # transactions to the Wise cache, and returns the balance. Same role as
    # `run_download` for BMO, but without a browser.
    try:
        api_token = read_config_text("wise.api_key")
    except TaskError as error:
        _say(f"Cannot read Wise: {error}")
        raise TaskError("Wise API token is missing.") from error
    try:
        profile_id = read_wise_id("wise.profile_id")
        balance_id = read_wise_id("wise.balance_id")
    except TaskError as error:
        _say(f"Cannot read Wise: {error}")
        raise

    to_date = datetime.date.today()
    from_date = to_date - datetime.timedelta(days=HISTORY_DAYS)
    transactions, balance = fetch_wise_data(
        api_token, profile_id, balance_id, from_date, to_date
    )
    save_wise_transactions(paths.wise_file, transactions)
    ctx.log(f"Wise transactions: {len(transactions)}, balance {format_amount(balance)}")
    _say(
        f"Got Wise balance {format_amount(balance)} "
        f"with {len(transactions)} transactions."
    )
    return balance


def read_wise_id(path):
    # Returns the Wise profile or balance ID at `path` in the configuration.
    # The file holds the ID as a string, and the API takes it as an integer.
    raw = read_config_text(path)
    text = raw.strip()
    if not text.isdigit():
        raise TaskError(f"{path} in ~/config.json is not a numeric ID")
    try:
        value = int(text)
    except ValueError:
        raise TaskError(f"{path} in ~/config.json is not a numeric ID") from None
    if value <= 0:
        raise TaskError(f"{path} in ~/config.json is not a numeric ID")
    return value


def fetch_wise_data(api_token, profile_id, balance_id, from_date, to_date):
    # Returns the transactions between `from_date` and `to_date` and the
    # current balance of the configured chequing account. That account maps
    # to the "Wise" account in YNAB.
    record = wise_get_balance(api_token, profile_id, balance_id)
    if not isinstance(record, dict):
        raise TaskError("Wise returned a bad balance")
    if record.get("currency") != WISE_CURRENCY:
        raise TaskError(
            f"Wise balance {balance_id} is in "
            f"{record.get('currency')!r}, expected {WISE_CURRENCY!r}"
        )
    if record.get("type") != "STANDARD":
        raise TaskError(f"Wise balance {balance_id} is not a chequing balance")
    balance = wise_balance_value(record)
    interval_start = from_date.strftime("%Y-%m-%dT00:00:00.000Z")
    interval_end = to_date.strftime("%Y-%m-%dT23:59:59.999Z")
    statement = wise_get_statement(
        api_token, profile_id, balance_id, interval_start, interval_end
    )
    transactions = [
        wise_to_transaction(item) for item in statement_transactions_of(statement)
    ]
    return transactions, balance


def wise_get_balance(api_token, profile_id, balance_id):
    # Returns one Wise balance, with its current amounts.
    return wise_get(
        f"read the Wise balance {balance_id}",
        f"{WISE_API_BASE}/v4/profiles/{profile_id}/balances/{balance_id}",
        api_token,
    )


def wise_get_statement(api_token, profile_id, balance_id, interval_start, interval_end):
    # Returns the statement of one Wise balance between the two UTC instants.
    query = urllib.parse.urlencode(
        {
            "currency": WISE_CURRENCY,
            "intervalStart": interval_start,
            "intervalEnd": interval_end,
            "type": "COMPACT",
        }
    )
    return wise_get(
        f"read the Wise statement of balance {balance_id}",
        f"{WISE_API_BASE}/v1/profiles/{profile_id}/balance-statements/"
        f"{balance_id}/statement.json?{query}",
        api_token,
    )


def statement_transactions_of(statement):
    # Returns the transaction items in a Wise statement.
    records = statement.get("transactions")
    if not isinstance(records, list):
        raise TaskError("Wise returned a statement without transactions")
    return records


def wise_balance_value(record):
    # Returns the current cash in a Wise balance. Prefers `cashAmount`, then
    # `amount`, then `totalWorth`.
    if not isinstance(record, dict):
        raise TaskError("Wise returned a bad balance")
    for key in ("cashAmount", "amount", "totalWorth"):
        amount = wise_amount_value(record.get(key), f"Wise balance field {key}")
        if amount is not None:
            return amount
    raise TaskError("Wise returned a balance without an amount")


def wise_to_transaction(item):
    # Returns the task transaction for one Wise statement item. The Wise
    # amount already has the sign of `Transaction.amount`: negative for money
    # that the user loses.
    if not isinstance(item, dict):
        raise TaskError("Wise returned a bad transaction")
    bank_payee = wise_payee(item)
    return Transaction(
        date=parse_wise_date(item.get("date")),
        amount=parse_wise_signed_amount(item.get("amount")),
        payee=bank_payee,
        account=Account.WISE,
        bank_payee=bank_payee,
    )


def wise_payee(item):
    # Returns the bank payee name of one Wise statement item. The payee map
    # replaces it with the name of the user, same as for BMO. Prefers the
    # human description, then the merchant name, then the sender name.
    details = item.get("details")
    if not isinstance(details, dict):
        details = {}
    description = details.get("description")
    if isinstance(description, str) and description.strip():
        return description.strip()
    merchant = details.get("merchant")
    if isinstance(merchant, dict):
        merchant_name = merchant.get("name")
        if isinstance(merchant_name, str) and merchant_name.strip():
            return merchant_name.strip()
    sender_name = details.get("senderName")
    if isinstance(sender_name, str) and sender_name.strip():
        sender_name = sender_name.strip()
        reference = details.get("paymentReference")
        if isinstance(reference, str) and reference.strip():
            return f"{sender_name} {reference.strip()}"
        return sender_name
    detail_type = details.get("type")
    if isinstance(detail_type, str) and detail_type.strip():
        return detail_type.strip()
    reference_number = item.get("referenceNumber")
    if isinstance(reference_number, str) and reference_number.strip():
        return reference_number.strip()
    return "Wise transaction"


def parse_wise_date(value):
    # Returns the date of a Wise ISO timestamp, such as
    # `2018-04-30T08:47:05.832Z`.
    if not isinstance(value, str) or not value.strip():
        raise TaskError(f"Wise returned a bad date {value!r}")
    text = value.strip().replace("Z", "+00:00")
    try:
        moment = datetime.datetime.fromisoformat(text)
    except ValueError:
        raise TaskError(f"Wise returned a bad date {value!r}") from None
    return moment.date()


def parse_wise_signed_amount(value):
    # Returns the signed amount of a Wise statement item, negative for debits.
    amount = wise_amount_value(value, "Wise transaction amount")
    if amount is None:
        raise TaskError(f"Wise returned a bad amount {value!r}")
    return amount


def wise_amount_value(value, what):
    # Returns the decimal value in `value`, an object with a `value` amount
    # such as `{"value": 310.86, "currency": "EUR"}`, or `None` when `value`
    # holds no such object. Raises when the object holds a bad amount.
    if value is None:
        return None
    if not isinstance(value, dict):
        raise TaskError(f"Wise returned a bad {what}: {value!r}")
    raw = value.get("value")
    if isinstance(raw, bool):
        raise TaskError(f"Wise returned a bad {what}: {raw!r}")
    if isinstance(raw, int):
        amount = decimal.Decimal(raw)
    elif isinstance(raw, decimal.Decimal):
        amount = raw
    elif isinstance(raw, float):
        amount = decimal.Decimal(str(raw))
    elif isinstance(raw, str) and raw.strip():
        try:
            amount = decimal.Decimal(raw.strip())
        except decimal.InvalidOperation:
            raise TaskError(f"Wise returned a bad {what}: {raw!r}") from None
    else:
        raise TaskError(f"Wise returned a bad {what}: {raw!r}")
    if not amount.is_finite():
        raise TaskError(f"Wise returned a bad {what}: {raw!r}")
    return amount


def save_wise_transactions(path, transactions):
    # Writes the Wise transactions to the cache at `path`, so `--no-download`
    # can reuse them. The cache holds plain JSON with ISO dates and string
    # amounts, so an exact decimal survives.
    data = [
        {
            "date": transaction.date.isoformat(),
            "amount": str(transaction.amount),
            "payee": transaction.payee,
        }
        for transaction in transactions
    ]
    try:
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=2)
            handle.write("\n")
        try:
            os.chmod(path, 0o600)
        except OSError:
            pass
    except OSError as error:
        raise TaskError(f"cannot save the Wise cache: {error}") from error


def read_wise_transactions(path):
    # Returns the Wise transactions in the cache at `path`.
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle, parse_float=decimal.Decimal)
    except FileNotFoundError:
        raise TaskError(
            "No downloaded statements. Run without --no-download first"
        ) from None
    except (OSError, ValueError) as error:
        raise TaskError(f"cannot read the Wise cache: {error}") from error
    if not isinstance(data, list):
        raise TaskError("the Wise cache holds no transaction list")
    transactions = []
    for entry in data:
        if not isinstance(entry, dict):
            raise TaskError("the Wise cache holds a bad transaction")
        try:
            date = datetime.date.fromisoformat(entry.get("date", ""))
        except (TypeError, ValueError):
            raise TaskError(
                f"the Wise cache holds a bad date {entry.get('date')!r}"
            ) from None
        raw_amount = entry.get("amount")
        if isinstance(raw_amount, bool):
            raise TaskError("the Wise cache holds a bad amount")
        if isinstance(raw_amount, (int, decimal.Decimal)):
            amount = decimal.Decimal(raw_amount)
        elif isinstance(raw_amount, float):
            amount = decimal.Decimal(str(raw_amount))
        elif isinstance(raw_amount, str):
            try:
                amount = decimal.Decimal(raw_amount.strip())
            except decimal.InvalidOperation:
                raise TaskError(
                    f"the Wise cache holds a bad amount {raw_amount!r}"
                ) from None
        else:
            raise TaskError(f"the Wise cache holds a bad amount {raw_amount!r}")
        if not amount.is_finite():
            raise TaskError(f"the Wise cache holds a bad amount {raw_amount!r}")
        payee = entry.get("payee")
        if not isinstance(payee, str) or not payee.strip():
            raise TaskError("the Wise cache holds a bad payee")
        transactions.append(
            Transaction(
                date=date,
                amount=amount,
                payee=payee,
                account=Account.WISE,
                bank_payee=payee,
            )
        )
    return transactions


def wise_get(action, url, api_token):
    # Returns the JSON body that the Wise API returns for `url`. A number
    # with a fraction becomes a `decimal.Decimal`, so an amount keeps its
    # exact value.
    try:
        response = urllib3.request(
            "GET",
            url,
            headers={"Authorization": f"Bearer {api_token}"},
            timeout=WISE_TIMEOUT_SECONDS,
        )
    except urllib3.exceptions.HTTPError as error:
        raise TaskError(f"cannot {action}: {error}") from error
    if response.status == 401:
        raise TaskError(
            f"cannot {action}: Wise rejected the token "
            f"({describe_wise_failure(response)})"
        )
    if response.status == 403:
        raise TaskError(
            f"cannot {action}: Wise refused the call "
            f"({describe_wise_failure(response)})"
        )
    if response.status != 200:
        raise TaskError(f"cannot {action}: {describe_wise_failure(response)}")
    try:
        value = json.loads(response.data, parse_float=decimal.Decimal)
    except ValueError as error:
        raise TaskError(
            f"cannot {action}: Wise returned invalid JSON: {error}"
        ) from error
    if not isinstance(value, (dict, list)):
        raise TaskError(f"cannot {action}: Wise returned no JSON object or list")
    return value


def describe_wise_failure(response):
    # Returns the HTTP status of `response`, with the message of the error
    # when the body holds one.
    description = f"HTTP {response.status}"
    try:
        body = json.loads(response.data)
    except ValueError:
        return description
    if isinstance(body, dict):
        for key in ("message", "error", "description"):
            message = body.get(key)
            if isinstance(message, str) and message.strip():
                return f"{description}, {message.strip()}"
    return description


# --------------------------------------------------------------------------------------
# YNAB.
# --------------------------------------------------------------------------------------

# The YNAB account of each statement.
YNAB_ACCOUNT_NAMES = {
    Account.CHEQUING: "BMO Chequing",
    Account.CREDIT_CARD: "BMO MasterCard",
    Account.WISE: "Wise",
}
ACCOUNTS_BY_YNAB_NAME = {name: account for account, name in YNAB_ACCOUNT_NAMES.items()}
# The YNAB account of all the Questrade accounts.
QUESTRADE_YNAB_ACCOUNT_NAME = "Questrade"
# The payee and the memo of the transaction of a reconciliation.
RECONCILIATION_PAYEE = "Balance Reconciliation"
RECONCILIATION_MEMO = "Balance reconciliation"
# YNAB amounts are in milliunits, thousandths of the unit of the currency.
MILLIUNITS_PER_UNIT = 1000
# YNAB takes payee names of at most this many characters.
YNAB_PAYEE_NAME_LIMIT = 200
# A payee such as `Transfer: BMO MasterCard` marks a transfer to the account
# that it names. A negative amount leaves the account of the statement for the
# named account, and a positive amount comes into it from the named account.
TRANSFER_PATTERN = re.compile(r"Transfer\s*:\s*(?P<account_name>.+)")


@dataclass
class YnabPayees:
    # The ID of each payee name that exactly one payee has.
    ids_by_name: dict
    # Every payee name, by its form without case.
    names_by_folded_name: dict


@dataclass
class YnabPlan:
    api_client: ynab.ApiClient
    plan_id: str
    # The ID of the YNAB account of each statement.
    account_ids: dict
    # The ID of the YNAB account of Questrade.
    questrade_account_id: uuid.UUID
    # The ID of the transfer payee of each open account of the plan, by the
    # name of the account. A transaction with that payee is a transfer to that
    # account. A name that more than one open account has is not here.
    transfer_payee_ids: dict
    # The name of every account of the plan, by its ID.
    account_names: dict
    # The payees that are not transfer payees.
    payees: YnabPayees


@dataclass
class YnabComparison:
    # The statement transactions that YNAB does not have.
    missing_transactions: list
    # For each account, the keys of the YNAB transactions that its statement
    # does not have. See `ynab_key` for the keys.
    extra_keys_by_account: dict
    # The YNAB transactions that match a statement transaction, but are not
    # cleared.
    uncleared_transactions: list
    # For each account, the keys that the statements expect in YNAB.
    expected_keys_by_account: dict
    # For each account, the YNAB transactions by key, in API order.
    ynab_by_key_by_account: dict
    # How many YNAB transactions in the period have no memo. After the
    # changes, the second comparison already includes the transactions that
    # the current run added.
    ynab_without_memo_count: int = 0


def save_to_ynab(
    ctx, transactions, decisions, start_date, bank_balances, questrade_balance,
    api_key, upload
):
    # Brings YNAB up to date with the statements, then compares the cleared
    # balances with `bank_balances`, then brings the YNAB account of
    # Questrade to `questrade_balance`. Returns whether YNAB matches the
    # statements, with the counts of added, cleared, deleted, and updated
    # transactions. Because of `--no-download`, `bank_balances` and
    # `questrade_balance` can be `None`, and the step of each one does not
    # run. Without `upload`, the task reads YNAB and reports the changes,
    # but changes nothing.
    with ynab.ApiClient(ynab.Configuration(access_token=api_key)) as api_client:
        plan = load_ynab_plan(api_client)
        matched, added_count, cleared_count, deleted_count, memo_count = (
            update_from_statements(ctx, plan, transactions, decisions, start_date, upload)
        )
        if bank_balances is None:
            _say("Bank balances skipped.")
        else:
            compare_bank_balances(plan, bank_balances, matched)
        if questrade_balance is None:
            _say("Questrade skipped.")
        else:
            reconcile_questrade(plan, questrade_balance, matched, upload)
    return matched, added_count, cleared_count, deleted_count, memo_count


def update_from_statements(ctx, plan, transactions, decisions, start_date, upload):
    # Adds to YNAB the statement transactions that it does not have, clears
    # the YNAB transactions that match a statement transaction but are not
    # cleared, and deletes the surplus YNAB copies of bank entries. The only
    # deletions in the task happen here. Leaves the YNAB transactions that no
    # statement holds as they are. Every read and check happens before the
    # first change, and a problem stops the task before any change. Without
    # `upload`, the task reads YNAB and reports the changes, but changes
    # nothing. Returns whether YNAB matches the statements at the end, with
    # the counts of added, cleared, and deleted transactions.
    comparison = compare_with_ynab(plan, transactions, start_date)
    report_ignored_counts(comparison)
    transactions_to_send, problems = plan_additions(
        plan, comparison.missing_transactions
    )
    if problems:
        _say("Blocked:\n" + "\n".join(problems))
        _say("Fix the names in YNAB or in `transactions.json` and rerun.")
        report_memo_count(comparison, start_date)
        raise TaskError("YNAB unchanged. Fix and rerun.")
    victims_by_account = deletable_transactions(comparison)
    doomed_ids = {
        victim.id for victims in victims_by_account.values() for victim in victims
    }
    memo_pushes = resolve_memo_mismatches(
        ctx,
        find_memo_mismatches(
            comparison, expected_memo_map(decisions), doomed_ids
        ),
        decisions,
    )

    missing_count = len(comparison.missing_transactions)
    uncleared_count = len(comparison.uncleared_transactions)
    delete_count = sum(len(victims) for victims in victims_by_account.values())
    memo_count = len(memo_pushes)
    if not missing_count and not uncleared_count and not delete_count and not memo_count:
        _say("YNAB already matches.")
        report_memo_count(comparison, start_date)
        return True, 0, 0, 0, 0

    if missing_count:
        say_new_transactions(comparison.missing_transactions)
        transfers = [
            transaction
            for transaction in transactions_to_send
            if transfer_target(transaction.payee) is not None
        ]
        if transfers:
            _say(f"{len(transfers)} transfer(s). YNAB adds each other side by itself.")
        report_other_sides(transfers)
    if uncleared_count:
        _say(f"Clear {uncleared_count} in YNAB.")
    if delete_count:
        say_deleted_transactions(victims_by_account)
    if memo_count:
        say_memo_updates(memo_pushes)
    if not upload:
        _say("Preview only. YNAB unchanged.")
        report_memo_count(comparison, start_date)
        return False, 0, 0, 0, 0
    changes = []
    if missing_count:
        changes.append(f"add {missing_count}")
    if uncleared_count:
        changes.append(f"clear {uncleared_count}")
    if delete_count:
        changes.append(f"delete {delete_count}")
    if memo_count:
        changes.append(f"update {memo_count} memos")
    if not ask_yes(f"In YNAB, {' and '.join(changes)}?"):
        _say("Cancelled. YNAB unchanged.")
        report_memo_count(comparison, start_date)
        return False, 0, 0, 0, 0

    if missing_count:
        send_transactions(ctx, plan, transactions_to_send, decisions)
    if uncleared_count:
        clear_ynab_transactions(plan, comparison.uncleared_transactions)
    if memo_count:
        update_ynab_memos(plan, memo_pushes)
    if delete_count:
        delete_ynab_transactions(plan, victims_by_account)
    deleted_keys_by_account = {
        account: [ynab_key(plan, victim) for victim in victims]
        for account, victims in victims_by_account.items()
    }

    # The second comparison also covers the sides of the transfers that YNAB
    # added by itself. After the changes, YNAB must have every statement
    # transaction as cleared, and no extra transaction beyond the ones that
    # it already held outside the statements.
    result = compare_with_ynab(plan, transactions, start_date)
    if (
        result.missing_transactions
        or result.uncleared_transactions
        or remaining_extra_keys(result, comparison, deleted_keys_by_account)
    ):
        log_ynab_differences(result)
        _say("YNAB still differs. Check YNAB.")
        report_memo_count(result, start_date)
        raise TaskError("YNAB differs after the changes.")
    _say(
        f"Added {missing_count}, cleared {uncleared_count}, "
        f"deleted {delete_count}, updated {memo_count} memos."
    )
    report_memo_count(result, start_date)
    return True, missing_count, uncleared_count, delete_count, memo_count


def remaining_extra_keys(result, comparison, deleted_keys_by_account):
    # Returns whether `result` holds extra YNAB keys beyond the ones outside
    # the statements and the ones that the run deleted. Compares each
    # account as a multiset.
    for account in YNAB_ACCOUNT_NAMES:
        expected = collections.Counter(
            comparison.extra_keys_by_account.get(account, [])
        )
        expected.subtract(
            collections.Counter(deleted_keys_by_account.get(account, []))
        )
        if collections.Counter(result.extra_keys_by_account.get(account, [])) != expected:
            return True
    return False


def deletable_transactions(comparison):
    # Returns the surplus YNAB copies of bank entries, by account. These are
    # the only transactions the task ever deletes. Takes uncleared copies
    # first, then the rest in API order. Raises when a victim is one leg
    # of a transfer, which needs a hand fix.
    victims_by_account = {}
    for account in YNAB_ACCOUNT_NAMES:
        expected = comparison.expected_keys_by_account.get(account, set())
        surplus = collections.Counter(
            key
            for key in comparison.extra_keys_by_account.get(account, [])
            if key in expected
        )
        if not surplus:
            continue
        ynab_by_key = comparison.ynab_by_key_by_account.get(account, {})
        victims = []
        for key, count in surplus.items():
            copies = ynab_by_key.get(key, [])
            ordered = sorted(
                copies,
                key=lambda item: item.cleared != ynab.TransactionClearedStatus.UNCLEARED,
            )
            victims.extend(ordered[:count])
        transfer_victims = [
            victim for victim in victims if victim.transfer_account_id is not None
        ]
        if transfer_victims:
            lines = [describe_ynab_transaction(victim) for victim in transfer_victims]
            raise TaskError(
                "YNAB holds surplus transfer legs. Fix them by hand:\n"
                + "\n".join(lines)
            )
        victims_by_account[account] = victims
    return victims_by_account


def say_deleted_transactions(victims_by_account):
    # Reports the YNAB transactions that the run deletes.
    victims = [
        victim
        for account in YNAB_ACCOUNT_NAMES
        for victim in victims_by_account.get(account, [])
    ]
    lines = [f"Delete ({len(victims)}):"]
    for victim in victims[:REPORT_LINE_LIMIT]:
        payee = victim.payee_name or ""
        if len(payee) > 20:
            payee = payee[:19] + "…"
        lines.append(
            f"{victim.var_date.strftime('%m-%d')} "
            f"{format_amount(from_milliunits(victim.amount))} {payee}"
        )
    if len(victims) > REPORT_LINE_LIMIT:
        lines.append(f"+{len(victims) - REPORT_LINE_LIMIT} more")
    _say("\n".join(lines))


def compare_bank_balances(plan, bank_balances, ynab_matches_statements):
    # Sends one short line per account with the balance at the bank and the
    # cleared balance in YNAB, plus one line per difference.
    # `bank_balances` maps each account to its balance at the bank, or to
    # `None` when the task could not read it. `ynab_matches_statements`
    # tells whether YNAB has every statement transaction, as cleared.
    lines = []
    differences = 0
    for account, ynab_name in YNAB_ACCOUNT_NAMES.items():
        tag = ACCOUNT_TAGS[account]
        ynab_account = read_ynab_account(plan, plan.account_ids[account])
        ynab_balance = from_milliunits(ynab_account.cleared_balance)
        bank_balance = bank_balances.get(account)
        if bank_balance is None:
            lines.append(f"{tag} bank ? / {format_amount(ynab_balance)}")
            continue
        difference = bank_balance - ynab_balance
        mark = "OK" if difference == 0 else "DIFF"
        if difference != 0:
            differences += 1
        lines.append(
            f"{tag} {format_amount(bank_balance)} / "
            f"{format_amount(ynab_balance)} {mark}"
        )
    _say("Bank / YNAB:\n" + "\n".join(lines))
    if differences and not ynab_matches_statements:
        _say("Pending changes can cause the diffs.")
    _log(f"bank balance differences: {differences}")


def reconcile_questrade(plan, questrade_balance, ynab_matches_statements, upload):
    # Adds a transaction to the YNAB account of Questrade that brings its
    # balance to `questrade_balance`. The YNAB balance includes the side of
    # each transfer from a statement, cleared or not. So the transaction
    # waits until YNAB matches the statements, which
    # `ynab_matches_statements` tells. Without `upload`, the task reports the
    # difference, but changes nothing. The balance goes to YNAB only once a
    # day: when the account already has a reconciliation transaction dated
    # today, the task reports the difference, but changes nothing.
    ynab_account = read_ynab_account(plan, plan.questrade_account_id)
    ynab_balance = from_milliunits(ynab_account.balance)
    difference = questrade_balance - ynab_balance
    mark = "OK" if difference == 0 else "DIFF"
    _say(
        f"QT {format_amount(questrade_balance)} / {format_amount(ynab_balance)} {mark}"
    )

    if difference == 0:
        _say("Questrade already matches.")
        return
    if not upload:
        _say("Preview only. YNAB unchanged.")
        return
    if not ynab_matches_statements:
        _say("Skipped: YNAB missed the statement changes.")
        return
    if questrade_reconciled_today(plan):
        _say("Skipped: Questrade already reconciled today.")
        return
    if not ask_yes(f"Add QT {format_amount(difference)}?"):
        _say("Cancelled. YNAB unchanged.")
        return

    send_reconciliation(plan, difference)
    ynab_account = read_ynab_account(plan, plan.questrade_account_id)
    new_balance = from_milliunits(ynab_account.balance)
    if new_balance != questrade_balance:
        _say("QT differs after the change. Check YNAB.")
        raise TaskError("Questrade differs after the reconciliation.")
    _say(f"QT {format_amount(difference)} added.")


def questrade_reconciled_today(plan):
    # Returns whether the YNAB account of Questrade already has a
    # reconciliation transaction dated today, deleted transactions aside.
    today = datetime.date.today()
    ynab_transactions = call_ynab(
        "read the Questrade transactions",
        ynab.TransactionsApi(plan.api_client).get_transactions_by_account,
        plan.plan_id,
        str(plan.questrade_account_id),
        since_date=today,
    )
    for ynab_transaction in ynab_transactions.data.transactions:
        if ynab_transaction.deleted:
            continue
        if ynab_transaction.var_date != today:
            continue
        if ynab_transaction.payee_name != RECONCILIATION_PAYEE:
            continue
        return True
    return False


def load_ynab_plan(api_client):
    plans = call_ynab("read the YNAB plans", ynab.PlansApi(api_client).get_plans)
    plans = plans.data.plans
    if len(plans) != 1:
        plan_names = ", ".join(plan.name for plan in plans) or "none"
        raise TaskError(f"expected one YNAB plan, found {len(plans)}")
    plan_id = str(plans[0].id)

    accounts = call_ynab(
        "read the YNAB accounts", ynab.AccountsApi(api_client).get_accounts, plan_id
    )
    accounts = [account for account in accounts.data.accounts if not account.deleted]
    account_ids = {
        account: find_open_account_id(accounts, account_name)
        for account, account_name in YNAB_ACCOUNT_NAMES.items()
    }
    questrade_account_id = find_open_account_id(accounts, QUESTRADE_YNAB_ACCOUNT_NAME)

    # A transfer names its other account, so a name that more than one open
    # account has cannot be the other side of a transfer.
    open_accounts = [
        ynab_account for ynab_account in accounts if not ynab_account.closed
    ]
    open_name_counts = collections.Counter(
        ynab_account.name for ynab_account in open_accounts
    )
    transfer_payee_ids = {
        ynab_account.name: ynab_account.transfer_payee_id
        for ynab_account in open_accounts
        if open_name_counts[ynab_account.name] == 1
    }

    payees = call_ynab(
        "read the YNAB payees", ynab.PayeesApi(api_client).get_payees, plan_id
    )
    payees = [
        payee
        for payee in payees.data.payees
        if not payee.deleted and payee.transfer_account_id is None
    ]
    name_counts = collections.Counter(payee.name for payee in payees)
    names_by_folded_name = collections.defaultdict(set)
    for payee in payees:
        names_by_folded_name[payee.name.casefold()].add(payee.name)

    return YnabPlan(
        api_client=api_client,
        plan_id=plan_id,
        account_ids=account_ids,
        questrade_account_id=questrade_account_id,
        transfer_payee_ids=transfer_payee_ids,
        account_names={account.id: account.name for account in accounts},
        payees=YnabPayees(
            ids_by_name={
                payee.name: payee.id for payee in payees if name_counts[payee.name] == 1
            },
            names_by_folded_name=dict(names_by_folded_name),
        ),
    )


def find_open_account_id(accounts, account_name):
    # Returns the ID of the only open account in `accounts` with the name
    # `account_name`.
    matches = [
        ynab_account
        for ynab_account in accounts
        if ynab_account.name == account_name and not ynab_account.closed
    ]
    if len(matches) != 1:
        raise TaskError(
            f"expected one open YNAB account named '{account_name}', found "
            f"{len(matches)}"
        )
    return matches[0].id


def compare_with_ynab(plan, transactions, start_date):
    missing_transactions = []
    extra_keys_by_account = {}
    uncleared_transactions = []
    expected_keys_by_account = {}
    ynab_by_key_by_account = {}
    ynab_without_memo_count = 0
    for account, account_id in plan.account_ids.items():
        ynab_transactions = call_ynab(
            "read the YNAB transactions",
            ynab.TransactionsApi(plan.api_client).get_transactions_by_account,
            plan.plan_id,
            str(account_id),
            since_date=start_date,
        )
        statement_transactions = [
            transaction
            for transaction in transactions
            if transaction.account == account
        ]
        visible_transactions = [
            ynab_transaction
            for ynab_transaction in ynab_transactions.data.transactions
            if not ynab_transaction.deleted
        ]
        ynab_without_memo_count += sum(
            1
            for ynab_transaction in visible_transactions
            if ynab_transaction.var_date >= start_date
            and ynab_memo_missing(ynab_transaction)
        )
        missing, extra_keys, uncleared, expected_keys, ynab_by_key = compare_account(
            plan,
            statement_transactions,
            visible_transactions,
        )
        missing_transactions += missing
        if extra_keys:
            extra_keys_by_account[account] = extra_keys
        uncleared_transactions += uncleared
        expected_keys_by_account[account] = expected_keys
        ynab_by_key_by_account[account] = ynab_by_key
    return YnabComparison(
        missing_transactions,
        extra_keys_by_account,
        uncleared_transactions,
        expected_keys_by_account,
        ynab_by_key_by_account,
        ynab_without_memo_count,
    )


def compare_account(plan, statement_transactions, ynab_transactions):
    # Returns the statement transactions that YNAB does not have, the keys of
    # the YNAB transactions that the statement does not have, the YNAB
    # transactions that match a statement transaction but are not cleared,
    # the keys that the statements expect, and the YNAB transactions by key.
    # Each key counts as many times as it appears, so two equal transactions
    # on a date need two in YNAB.
    statement_counts = collections.Counter(map(statement_key, statement_transactions))
    ynab_keys = [
        ynab_key(plan, ynab_transaction) for ynab_transaction in ynab_transactions
    ]
    ynab_counts = collections.Counter(ynab_keys)
    ynab_by_key = collections.defaultdict(list)
    for key, ynab_transaction in zip(ynab_keys, ynab_transactions):
        ynab_by_key[key].append(ynab_transaction)

    missing_counts = statement_counts - ynab_counts
    missing_transactions = []
    for transaction in statement_transactions:
        key = statement_key(transaction)
        if missing_counts[key] > 0:
            missing_counts[key] -= 1
            missing_transactions.append(transaction)

    extra_keys = sorted((ynab_counts - statement_counts).elements())

    # The cleared YNAB transactions take the matches first, and the uncleared
    # ones take the rest. The sort keeps the order of YNAB within each group.
    unmatched_counts = statement_counts.copy()
    uncleared_transactions = []
    for key, ynab_transaction in sorted(
        zip(ynab_keys, ynab_transactions),
        key=lambda pair: pair[1].cleared == ynab.TransactionClearedStatus.UNCLEARED,
    ):
        if unmatched_counts[key] == 0:
            continue
        unmatched_counts[key] -= 1
        if ynab_transaction.cleared == ynab.TransactionClearedStatus.UNCLEARED:
            uncleared_transactions.append(ynab_transaction)
    return (
        missing_transactions,
        extra_keys,
        uncleared_transactions,
        set(statement_counts),
        dict(ynab_by_key),
    )


def statement_key(transaction):
    # The date, the payee, and the amount in milliunits. The payee of a
    # transfer is `Transfer: <account name>`, whatever its spacing in the
    # decision.
    target_name = transfer_target(transaction.payee)
    payee = transaction.payee if target_name is None else transfer_payee(target_name)
    return (transaction.date, payee, to_milliunits(transaction.amount))


def ynab_key(plan, ynab_transaction):
    # The key of a YNAB transaction, in the form of `statement_key`. YNAB
    # names transfer payees in a format of its own, so the payee of a
    # transfer comes from the account at the other side.
    transfer_account_id = ynab_transaction.transfer_account_id
    if transfer_account_id is None:
        payee = ynab_transaction.payee_name or ""
    else:
        payee = transfer_payee(
            plan.account_names.get(transfer_account_id, str(transfer_account_id))
        )
    return (ynab_transaction.var_date, payee, ynab_transaction.amount)


def transfer_target(payee):
    # Returns the name of the account that `payee` names as the other side of
    # a transfer, or `None` when `payee` does not mark a transfer.
    match = TRANSFER_PATTERN.fullmatch(payee)
    return None if match is None else match["account_name"].strip()


def transfer_payee(account_name):
    return f"Transfer: {account_name}"


def plan_additions(plan, missing_transactions):
    # Returns the transactions to send to YNAB, and the problems that stop
    # every addition. YNAB adds the other side of a transfer by itself, on the
    # same date, so only one side goes to YNAB. A transfer between two
    # accounts with statements needs both of its sides among the missing
    # transactions, and the side of the first account in the order of
    # `Account` goes to YNAB. A transfer to an account without a statement
    # has only the one side.
    transactions_to_send = []
    problems = []
    # The missing sides of the transfers, by date, the two accounts in the
    # order of `Account`, and the amount for the first account.
    transfer_sides = collections.defaultdict(lambda: ([], []))
    for transaction in missing_transactions:
        target_name = transfer_target(transaction.payee)
        if target_name is None:
            problem = find_payee_problem(plan.payees, transaction.payee)
            if problem is None:
                transactions_to_send.append(transaction)
            elif problem not in problems:
                problems.append(problem)
            continue

        own_name = YNAB_ACCOUNT_NAMES[transaction.account]
        if target_name == own_name or target_name not in plan.transfer_payee_ids:
            if target_name == own_name:
                reason = "transfer to its own account"
            else:
                reason = f"no open YNAB account {target_name!r}"
            problems.append(f"{compact_line(transaction)}: {reason}")
            continue

        target_account = ACCOUNTS_BY_YNAB_NAME.get(target_name)
        if target_account is None:
            transactions_to_send.append(transaction)
            continue
        if transaction.account < target_account:
            key = (transaction.date, transaction.account, target_account)
            transfer_sides[(*key, transaction.amount)][0].append(transaction)
        else:
            key = (transaction.date, target_account, transaction.account)
            transfer_sides[(*key, -transaction.amount)][1].append(transaction)

    for key, (first_sides, second_sides) in transfer_sides.items():
        pair_count = min(len(first_sides), len(second_sides))
        transactions_to_send += first_sides[:pair_count]
        if len(first_sides) != len(second_sides):
            problems.append(
                describe_unpaired_transfers(key, len(first_sides), len(second_sides))
            )
    return transactions_to_send, problems


def describe_unpaired_transfers(key, first_count, second_count):
    # `key` holds the date, the two accounts in the order of `Account`, and
    # the amount for the first account. The counts are the missing sides in
    # the statement of each account.
    date, first_account, second_account, amount = key
    first_name = YNAB_ACCOUNT_NAMES[first_account]
    second_name = YNAB_ACCOUNT_NAMES[second_account]
    if amount < 0:
        source_name, destination_name = first_name, second_name
    else:
        source_name, destination_name = second_name, first_name
    return (
        f"on {date.isoformat()}, {first_name} has {first_count} and "
        f"{second_name} has {second_count} transfers of "
        f"{format_amount(abs(amount))} from {source_name} to {destination_name}"
    )


def find_payee_problem(payees, payee):
    # Returns why a transaction with `payee` cannot go to YNAB, or `None` when
    # it can.
    if len(payee) > YNAB_PAYEE_NAME_LIMIT:
        return f"{payee[:40]}… is over the YNAB payee limit"
    if payee in payees.ids_by_name:
        return None
    other_names = payees.names_by_folded_name.get(payee.casefold(), set()) - {payee}
    if other_names:
        quoted_names = ", ".join(f"'{name}'" for name in sorted(other_names))
        return f"{payee!r} differs only in case from {quoted_names}"
    return None


def ask_memo(transaction):
    # Asks for the memo of `transaction`, and returns it. Returns None when
    # the reply is a dash, which means no memo.
    reply = _CTX.ask(
        f"{compact_line(transaction)}\nReply with the memo, or - for none.",
        pattern=r"[\s\S]+",
        timeout=300,
    )
    memo = reply.strip()
    return None if memo == "-" or not memo else memo


def send_transactions(ctx, plan, transactions, decisions):
    # Asks for a memo for each of `transactions` without a stored memo, then
    # adds them to YNAB. Stores the new single memos in `decisions`. Split
    # parts always hold their memos already. The Questrade reconciliation
    # keeps its own memo, so it does not come through here. See
    # `send_reconciliation`.
    for transaction in sorted(transactions, key=report_order):
        if not transaction.memo_ready:
            transaction.memo = ask_memo(transaction)
    rows = {decision["key"]: decision for decision in decisions}
    changed = False
    for transaction in transactions:
        if transaction.memo_ready:
            continue
        row = rows.get(transaction_decision_key(transaction))
        if row is None or row["kind"] != "single":
            continue
        row["memo"] = transaction.memo
        row["memo_ready"] = True
        transaction.memo_ready = True
        changed = True
    if changed:
        save_decisions(ctx, decisions)
    new_transactions = []
    for transaction in transactions:
        target_name = transfer_target(transaction.payee)
        if target_name is None:
            # The ID makes YNAB use the payee with exactly this name. Without
            # one, YNAB looks the name up, or creates a payee with it.
            payee_id = plan.payees.ids_by_name.get(transaction.payee)
            payee_name = transaction.payee
        else:
            # The transfer payee of the account at the other side makes the
            # transaction a transfer.
            payee_id = plan.transfer_payee_ids[target_name]
            payee_name = None
        new_transactions.append(
            ynab.NewTransaction(
                account_id=plan.account_ids[transaction.account],
                var_date=transaction.date,
                amount=to_milliunits(transaction.amount),
                payee_id=payee_id,
                payee_name=payee_name,
                memo=transaction.memo,
                cleared=ynab.TransactionClearedStatus.CLEARED,
                approved=False,
            )
        )
    create_ynab_transactions(plan, new_transactions)


def send_reconciliation(plan, amount):
    # Adds a transaction of `amount` to the YNAB account of Questrade, on the
    # date of today. The payee ID makes YNAB use the payee with exactly this
    # name. Without one, YNAB looks the name up, or creates a payee with it.
    transaction = ynab.NewTransaction(
        account_id=plan.questrade_account_id,
        var_date=datetime.date.today(),
        amount=to_milliunits(amount),
        payee_id=plan.payees.ids_by_name.get(RECONCILIATION_PAYEE),
        payee_name=RECONCILIATION_PAYEE,
        memo=RECONCILIATION_MEMO,
        cleared=ynab.TransactionClearedStatus.CLEARED,
        approved=False,
    )
    create_ynab_transactions(plan, [transaction])


def create_ynab_transactions(plan, new_transactions):
    # Adds `new_transactions` to YNAB. Each one must be cleared and not
    # approved. YNAB adds the other side of each transfer by itself, with a
    # status of its own, so each other side then becomes cleared and not
    # approved too. Last, raises when YNAB holds any of these transactions as
    # approved or not cleared.
    transactions_api = ynab.TransactionsApi(plan.api_client)
    try:
        response = transactions_api.create_transaction(
            plan.plan_id, ynab.PostTransactionsWrapper(transactions=new_transactions)
        )
    except YNAB_ERRORS as error:
        raise TaskError(f"cannot add the transactions to YNAB: {error}") from error
    # The last state of each transaction, by its ID.
    saved_transactions = {
        transaction.id: transaction for transaction in saved_transactions_of(response)
    }

    other_side_ids = [
        transaction.transfer_transaction_id
        for transaction in saved_transactions.values()
        if transaction.transfer_account_id is not None
    ]
    if None in other_side_ids:
        raise TaskError("YNAB returned a transfer without its other side")
    if other_side_ids:
        updates = [
            ynab.SaveTransactionWithIdOrImportId(
                id=transaction_id,
                cleared=ynab.TransactionClearedStatus.CLEARED,
                approved=False,
            )
            for transaction_id in other_side_ids
        ]
        try:
            response = transactions_api.update_transactions(
                plan.plan_id, ynab.PatchTransactionsWrapper(transactions=updates)
            )
        except YNAB_ERRORS as error:
            raise TaskError(
                f"cannot update the other sides in YNAB: {error}"
            ) from error
        for transaction in saved_transactions_of(response):
            saved_transactions[transaction.id] = transaction

    wrong_transactions = [
        transaction
        for transaction in saved_transactions.values()
        if transaction.approved
        or transaction.cleared != ynab.TransactionClearedStatus.CLEARED
    ]
    if wrong_transactions:
        for transaction in wrong_transactions:
            _log(f"  {describe_ynab_transaction(transaction)}")
        raise TaskError("YNAB holds new transactions as approved or uncleared")


def clear_ynab_transactions(plan, ynab_transactions):
    # Makes each of `ynab_transactions` cleared, and leaves the rest of it as
    # it is, such as its approval.
    updates = [
        ynab.SaveTransactionWithIdOrImportId(
            id=ynab_transaction.id, cleared=ynab.TransactionClearedStatus.CLEARED
        )
        for ynab_transaction in ynab_transactions
    ]
    try:
        ynab.TransactionsApi(plan.api_client).update_transactions(
            plan.plan_id, ynab.PatchTransactionsWrapper(transactions=updates)
        )
    except YNAB_ERRORS as error:
        raise TaskError(f"cannot clear the transactions in YNAB: {error}") from error


def delete_ynab_transactions(plan, victims_by_account):
    # Deletes the given YNAB transactions. The caller passes only surplus
    # copies of bank entries, so this stays the only path that deletes.
    transactions_api = ynab.TransactionsApi(plan.api_client)
    delete_function = getattr(transactions_api, "delete_transaction", None)
    if not callable(delete_function):
        raise TaskError("the YNAB client cannot delete transactions")
    for account in YNAB_ACCOUNT_NAMES:
        for victim in victims_by_account.get(account, []):
            call_ynab(
                f"delete the YNAB transaction {victim.id}",
                delete_function,
                plan.plan_id,
                str(victim.id),
            )


def expected_memo_map(decisions):
    # Returns the expected YNAB memo by statement key, with the decision row
    # and part index behind each one. Skips rows without a stored memo and
    # keys with more than one memo, which need no check.
    memo_map = {}
    ambiguous_keys = set()
    for decision in decisions:
        source, date_iso, _bank_payee, bank_amount = decision["key"]
        account = ACCOUNTS_BY_SOURCE[source]
        date = datetime.date.fromisoformat(date_iso)
        if decision["kind"] == "single":
            if not decision["memo_ready"]:
                continue
            candidates = [(decision["payee"], bank_amount, decision["memo"], None)]
        else:
            candidates = [
                (part["payee"], part["amount"], part["memo"], part_index)
                for part_index, part in enumerate(decision["parts"])
            ]
        for payee, amount, memo, part_index in candidates:
            key = statement_key(
                Transaction(date=date, amount=amount, payee=payee, account=account)
            )
            if key in memo_map:
                ambiguous_keys.add(key)
            else:
                memo_map[key] = {
                    "memo": memo,
                    "row": decision,
                    "part": part_index,
                }
    for key in ambiguous_keys:
        del memo_map[key]
    return memo_map


def normalize_memo(memo):
    # Returns the memo for comparison: stripped text, or "" for none.
    return (memo or "").strip()


def find_memo_mismatches(comparison, memo_map, doomed_ids):
    # Returns one item per statement key whose YNAB copies hold a different
    # memo than the decision stores. Skips doomed copies, which leave YNAB.
    mismatches = []
    for account in YNAB_ACCOUNT_NAMES:
        ynab_by_key = comparison.ynab_by_key_by_account.get(account, {})
        for key, entry in memo_map.items():
            copies = [
                candidate
                for candidate in ynab_by_key.get(key, [])
                if candidate.id not in doomed_ids
                and normalize_memo(candidate.memo) != normalize_memo(entry["memo"])
            ]
            if copies:
                mismatches.append(
                    {
                        "account": account,
                        "key": key,
                        "copies": copies,
                        "row": entry["row"],
                        "part": entry["part"],
                    }
                )
    return mismatches


def resolve_memo_mismatches(ctx, mismatches, decisions):
    # Asks about each memo mismatch and returns the YNAB copies to update
    # with their new memos. A database answer adopts the YNAB memo into the
    # decision row at once.
    push_items = []
    adopted = False
    for item in mismatches:
        stored = current_expected_memo(item)
        copies = [
            candidate
            for candidate in item["copies"]
            if normalize_memo(candidate.memo) != normalize_memo(stored)
        ]
        if not copies:
            continue
        if ask_memo_direction(
            ctx, item["account"], item["key"], stored, copies
        ):
            push_items.extend(
                {"account": item["account"], "key": item["key"], "txn": copy, "memo": stored}
                for copy in copies
            )
        else:
            adopt_ynab_memo(item, copies)
            adopted = True
    if adopted:
        save_decisions(ctx, decisions)
    return push_items


def current_expected_memo(item):
    # Returns the memo that the decision row of `item` currently stores.
    row = item["row"]
    if item["part"] is None:
        return row.get("memo")
    return row["parts"][item["part"]]["memo"]


def adopt_ynab_memo(item, copies):
    # Stores the most common YNAB memo of `copies` in the decision row of
    # `item`. Ties go to the first copy in API order. An empty memo stores
    # None, which means no memo.
    counts = collections.Counter(normalize_memo(copy.memo) for copy in copies)
    top_count = max(counts.values())
    adopted = next(
        normalize_memo(copy.memo)
        for copy in copies
        if counts[normalize_memo(copy.memo)] == top_count
    )
    value = adopted or None
    if item["part"] is None:
        item["row"]["memo"] = value
    else:
        item["row"]["parts"][item["part"]]["memo"] = value


def ask_memo_direction(ctx, account, key, stored, copies):
    # Asks whether the memo of one statement key goes to YNAB or to the
    # database. Returns True for YNAB.
    date, payee, milliunits = key
    if len(payee) > 20:
        payee = payee[:19] + "…"
    ynab_options = sorted({normalize_memo(copy.memo) for copy in copies})
    lines = [
        f"{date.strftime('%m-%d')} {ACCOUNT_TAGS[account]} "
        f"{format_amount(from_milliunits(milliunits))} {payee}",
        f"Database: {display_memo(stored)}",
        "YNAB: " + ", ".join(display_memo(option) for option in ynab_options),
        "Update YNAB or the database? Reply `ynab` or `db`.",
    ]
    return ctx.ask("\n".join(lines), pattern=r"(?i:ynab|db)", timeout=300).casefold() == "ynab"


def display_memo(memo):
    # Returns the memo for the chat: quoted text, or `(none)` for none.
    text = normalize_memo(memo)
    if not text:
        return "(none)"
    if len(text) > 30:
        text = text[:29] + "…"
    return f'"{text}"'


def update_ynab_memos(plan, push_items):
    # Sets the stored memo on the given YNAB transactions in one call.
    updates = [
        ynab.SaveTransactionWithIdOrImportId(id=item["txn"].id, memo=item["memo"])
        for item in push_items
    ]
    try:
        ynab.TransactionsApi(plan.api_client).update_transactions(
            plan.plan_id, ynab.PatchTransactionsWrapper(transactions=updates)
        )
    except YNAB_ERRORS as error:
        raise TaskError(f"cannot update the memos in YNAB: {error}") from error


def say_memo_updates(push_items):
    # Reports the YNAB memos that the run updates, one line per key.
    groups = {}
    for item in push_items:
        groups.setdefault((item["account"], item["key"]), []).append(item)
    lines = [f"Update memos ({len(push_items)}):"]
    for (account, key), items in list(groups.items())[:REPORT_LINE_LIMIT]:
        date, payee, milliunits = key
        if len(payee) > 20:
            payee = payee[:19] + "…"
        lines.append(
            f"{date.strftime('%m-%d')} {ACCOUNT_TAGS[account]} "
            f"{format_amount(from_milliunits(milliunits))} {payee} "
            f"-> {display_memo(items[0]['memo'])}"
        )
    if len(groups) > REPORT_LINE_LIMIT:
        lines.append(f"+{len(groups) - REPORT_LINE_LIMIT} more")
    _say("\n".join(lines))


def describe_ynab_transaction(ynab_transaction):
    # Returns the date, the amount, the payee, and the account of a YNAB
    # transaction, as `format_details` gives them.
    return format_details(
        ynab_transaction.var_date,
        from_milliunits(ynab_transaction.amount),
        ynab_transaction.payee_name or "",
        ynab_transaction.account_name,
    )


def saved_transactions_of(response):
    # Returns the transactions in a response of YNAB to a save. The response
    # holds a list of transactions, or one transaction.
    if response.data.transactions is not None:
        return response.data.transactions
    if response.data.transaction is not None:
        return [response.data.transaction]
    return []


def read_ynab_account(plan, account_id):
    # Returns the YNAB account with `account_id`, with its balances of now.
    account_name = plan.account_names.get(account_id, str(account_id))
    response = call_ynab(
        f"read the YNAB account '{account_name}'",
        ynab.AccountsApi(plan.api_client).get_account_by_id,
        plan.plan_id,
        account_id,
    )
    return response.data.account


def report_other_sides(transfers):
    # Sends the sides of `transfers` that YNAB adds by itself to accounts
    # without a statement. The task cannot check those accounts.
    other_sides = []
    for transfer in transfers:
        target_name = transfer_target(transfer.payee)
        if target_name in ACCOUNTS_BY_YNAB_NAME:
            continue
        other_sides.append(
            Transaction(
                date=transfer.date,
                amount=-transfer.amount,
                payee=transfer_payee(YNAB_ACCOUNT_NAMES[transfer.account]),
                account=transfer.account,
            )
        )
    if other_sides:
        lines = ["YNAB also adds:"]
        for side in other_sides:
            payee = side.payee
            if len(payee) > 20:
                payee = payee[:19] + "…"
            lines.append(
                f"{side.date.strftime('%m-%d')} {format_amount(side.amount)} {payee}"
            )
        lines.append("Check for doubles.")
        _say("\n".join(lines))


def report_ignored_counts(comparison):
    # Sends, for each account, how many YNAB transactions that no statement
    # holds the task leaves as they are. Surplus copies of bank entries are
    # deletions, not ignored entries.
    for account, ynab_name in YNAB_ACCOUNT_NAMES.items():
        expected = comparison.expected_keys_by_account.get(account, set())
        ignored = [
            key
            for key in comparison.extra_keys_by_account.get(account, [])
            if key not in expected
        ]
        if ignored:
            _log(f"Ignored {len(ignored)} in {ynab_name}, not in its statement")
            _say(f"Ignored {len(ignored)} in {ynab_name}, not in its statement.")


def ynab_memo_missing(ynab_transaction):
    # Returns whether the YNAB transaction has no memo. A memo with only
    # spaces counts as no memo, like a missing one.
    return not (getattr(ynab_transaction, "memo", None) or "").strip()


def report_memo_count(comparison, start_date):
    # Reports how many YNAB transactions in the period have no memo. The
    # count comes from the comparison, so after the changes it already
    # includes the transactions that the current run added.
    count = comparison.ynab_without_memo_count
    _log(f"transactions without a memo since {start_date.isoformat()}: {count}")
    _say(f"{count} transactions without a memo since {start_date.isoformat()}.")


def log_ynab_differences(comparison):
    # Logs the remaining differences after the changes, for the bot log.
    for account, ynab_name in YNAB_ACCOUNT_NAMES.items():
        extra_keys = comparison.extra_keys_by_account.get(account, [])
        missing_transactions = [
            transaction
            for transaction in comparison.missing_transactions
            if transaction.account == account
        ]
        uncleared_transactions = [
            ynab_transaction
            for ynab_transaction in comparison.uncleared_transactions
            if ynab_transaction.account_name == ynab_name
        ]
        if extra_keys:
            _log(f"{ynab_name} has {len(extra_keys)} extra in YNAB")
        for transaction in missing_transactions:
            _log(
                "  missing in YNAB: "
                + format_details(
                    transaction.date, transaction.amount, transaction.payee
                )
            )
        for ynab_transaction in uncleared_transactions:
            _log(f"  not cleared: {describe_ynab_transaction(ynab_transaction)}")


def to_milliunits(amount):
    milliunits = amount * MILLIUNITS_PER_UNIT
    if milliunits != milliunits.to_integral_value():
        raise TaskError(f"the amount {amount} has more than three decimals")
    return int(milliunits)


def from_milliunits(milliunits):
    return decimal.Decimal(milliunits) / MILLIUNITS_PER_UNIT


# The errors of a call of the YNAB API: an error response, or a failure of the
# connection.
YNAB_ERRORS = (ynab.ApiException, urllib3.exceptions.HTTPError)


def call_ynab(action, function, *arguments, **keyword_arguments):
    # Runs one call of the YNAB API. Raises with `action` in the message when
    # the call fails.
    try:
        return function(*arguments, **keyword_arguments)
    except YNAB_ERRORS as error:
        raise TaskError(f"cannot {action}: {error}") from error


# --------------------------------------------------------------------------------------
# Browser.
# --------------------------------------------------------------------------------------


class StepError(TaskError):
    # A step of the download failed.
    pass


@dataclass(frozen=True)
class Secret:
    # An argument of a command that messages must not show, such as a
    # password. The command gets `value`, and messages show `<hidden>`.
    value: str


class Browser:
    # Runs `agent-browser` commands, and records whether the browser is open.
    # A command runs in the session that `AGENT_BROWSER_SESSION` names.

    def __init__(self):
        self.opened = False

    def open(self, url, options):
        global _BROWSER_OPENED
        self.run(*options, "open", url)
        self.opened = True
        _BROWSER_OPENED = True

    def find_role(self, role, action, name, *values):
        # Runs `action` on the element with `role` and the accessible `name`.
        self.run("find", "role", role, action, *values, "--name", name)

    def run(self, *arguments, stdout=None):
        # Runs `agent-browser` with `arguments`, and returns what it wrote on
        # standard output when `stdout` is `subprocess.PIPE`. Raises
        # `StepError` when the command fails.
        result = run_agent_browser(arguments, stdout=stdout, stderr=None)
        if result.returncode != 0:
            raise StepError(
                f"`{describe_command(arguments)}` failed with exit status "
                f"{result.returncode}"
            )
        return result.stdout

    def succeeds(self, *arguments):
        # Runs `agent-browser` with `arguments`, without output, and returns
        # whether it succeeded.
        result = run_agent_browser(
            arguments, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        return result.returncode == 0


def run_agent_browser(arguments, stdout, stderr):
    command = [
        "agent-browser",
        *(
            argument.value if isinstance(argument, Secret) else argument
            for argument in arguments
        ),
    ]
    try:
        return subprocess.run(
            command, stdout=stdout, stderr=stderr, encoding="utf-8", errors="replace"
        )
    except OSError as error:
        raise StepError(f"cannot run agent-browser: {error}") from error


def describe_command(arguments):
    # Returns the command as messages show it, with every `Secret` hidden.
    return shlex.join(
        [
            "agent-browser",
            *(
                "<hidden>" if isinstance(argument, Secret) else argument
                for argument in arguments
            ),
        ]
    )
