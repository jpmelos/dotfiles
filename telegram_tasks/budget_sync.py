# Task that downloads the bank statements and syncs new transactions and
# balances to YNAB.
#
# Run it with `/budget_sync` from the allowlisted chat. Optional words
# after the name are `--no-download`, `--no-upload`, and
# `--questrade-config-token`.
#
# BMO comes from `agent-browser` downloads. Wise comes from the Wise API with
# the token in `wise.api_key`, without a browser. The Wise cache lives in
# the task state directory as JSON, so `--no-download` reuses the last Wise
# fetch, same as it reuses the last BMO statements. The balances cache lives
# there too, so `--no-download` still sends the last BMO, Wise, and Questrade
# balances to YNAB.
#
# Every bank entry needs a decision in `transactions.json` in the task state:
# its YNAB payee and memo, or its split parts with payee, amount, and memo
# each. The task lists new entries and asks for splits first, then asks
# about YNAB transfers missing a side, then asks payees in date order and
# remembers. Each payee question downloads all YNAB payees, sends the past
# bank to YNAB choices of the last 90 days with them to the LLM, asks for
# the three most likely matches, and shows them as a numbered list. A number
# picks a match, and a name picks or creates a payee. A new payee needs
# confirmation. One decision covers every identical entry of one day.
# Decision rows older than 90 days go away automatically.
# When YNAB already holds the same account, date, and
# amount, the task offers its payee and memo first, and an accepted offer
# becomes the decision with nothing else to ask. Nearby managed transfers
# within 7 days also offer, since YNAB keeps both legs on the earliest bank
# date. A transfer looks for its other end within 7 days and shares one
# memo. Single-sided transfers go to YNAB in the same run, since YNAB adds
# the other side by itself. The statement leg goes as cleared, and the
# other side stays uncleared until its statement appears, when the uncleared
# flow clears it. Pairs with both legs present go as cleared on both sides.
# Later runs match new entries to YNAB transfers missing a side, after the
# split question.
# YNAB keeps both legs of a transfer on one date: the earliest bank date of
# the pair. Bank pairs on different days still match that single YNAB date,
# in the flow to register new transactions and in future runs. Pairs dated
# after the early leg move to the earliest date after one confirmation.
# YNAB gains missing copies and loses surplus copies of bank entries after
# one confirmation. Deletion happens only there. Before that, the task syncs
# every recognized YNAB transaction with the database: entries with the same
# account, date, and amount compare payees and memos as multisets, so several
# transactions of one amount with different memos each need a match, either
# whole or split into parts. A mismatch asks whether YNAB or the database
# wins, then makes both sides match, after one confirmation of its own. Each
# side of a transfer between managed accounts checks its payee on its own.
# The pair shares its memo: the first side asked sets it, and the other side
# is offered that memo with a yes or no question instead of retyping it,
# while any leftover mismatch asks once for the pair. Both legs and both
# database sides hold the same memo once all is done, as YNAB requires. New
# transfers send only one side, since YNAB adds the other side by itself.
# Balance lines show cleared YNAB balances, which leave out uncleared other
# sides, so they match what the banks report. The chat gets the new
# transactions and the ignored
# account, one line each with the full payee, plus short confirmations,
# one combined balance message, and a count of the transactions without a memo.

NAME = "budget_sync"
DESCRIPTION = (
    "Sync new BMO and Wise transactions and BMO, Wise, and Questrade "
    "balances to YNAB."
)
HELP = (
    "Flags:\n"
    "--no-download: reuse the last statements and balances.\n"
    "--no-upload: preview only, YNAB stays unchanged.\n"
    "--questrade-config-token: redeem the config Questrade token "
    "instead of the saved one."
)
SHORTHAND = "b"
MENU = True
# Banking with user questions can take a while. This is the budget for one
# run, in seconds.
TIMEOUT = 7200

# Requirement strings that the bot installs with `uv` into the venv of the
# task on every run.
DEPENDENCIES = (
    "ynab>=4.4.0,<5",
    "urllib3>=2,<3",
    "click>=8,<9",
    "openai>=1,<2",
)

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

import click
import urllib3
import ynab

# YNAB guesses a category when the create payload omits `category_id`. The
# SDK drops an explicit `category_id=None`, so send an explicit null instead.
_original_new_transaction_to_dict = ynab.NewTransaction.to_dict


def _new_transaction_to_dict_with_null_category(self):
    data = _original_new_transaction_to_dict(self)
    if self.category_id is None and "category_id" in self.model_fields_set:
        data["category_id"] = None
    return data


ynab.NewTransaction.to_dict = _new_transaction_to_dict_with_null_category

LOGIN_URL = "https://www1.bmo.com/banking/digital/"
# The `agent-browser` session of this task. A session of its own keeps the
# task from sharing a browser with other uses of `agent-browser`.
BROWSER_SESSION = "budget-sync"
# How long to wait for a page to load, and for a download to finish.
PAGE_WAIT_SECONDS = 5
DOWNLOAD_WAIT_SECONDS = 10
# How many days back the task looks. The task ignores the transactions before
# the start date, in the statements and in YNAB.
HISTORY_DAYS = 30
# How many days a decision row stays in `transactions.json`. Older rows go
# away automatically on every run.
DECISION_RETENTION_DAYS = 90
# How many days apart the two ends of a transfer may appear. The task looks
# for the other end in the same day and this many days before and after.
TRANSFER_MATCH_DAYS = 7
# The first date of the transactions to process.
DEFAULT_FROM_DATE = datetime.date(2026, 10, 1)
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
BALANCES_ID = "balances.json"
DOWNLOAD_ID = "statement.csv"
SESSION_ID = "bmo_session.json"
TOKEN_ID = "questrade_refresh_token.txt"
SCREENSHOT_ID = "browser-error.png"
# When the last run finished, as an ISO timestamp. Other tasks read it to
# check whether this task ran today.
LAST_RUN_ID = "last_run.json"
# How many new transactions the chat report lists before it summarizes.
REPORT_LINE_LIMIT = 60


# -----------------------------------------------------------------------------
# Task entry points.
# -----------------------------------------------------------------------------

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
    no_download, no_upload, questrade_config_token = parse_task_args(
        list(args or [])
    )
    ctx.say("Budget sync started.")
    try:
        ynab_api_key = read_config_text("ynab.api_key")
    except TaskError as error:
        _say(f"Cannot start: {error}")
        raise TaskError("YNAB API key is missing.") from error
    paths = resolve_state_files(ctx)
    # The task works only on the transactions from this date on, in the
    # statements and in YNAB.
    start_date = max(
        DEFAULT_FROM_DATE,
        datetime.date.today() - datetime.timedelta(days=HISTORY_DAYS),
    )
    if no_download:
        if questrade_config_token:
            _say(
                "--questrade-config-token needs a download, so it has no "
                "effect with --no-download."
            )
        use_last_statements(paths)
        balances, questrade_balance = load_balances(ctx)
        if balances is None and questrade_balance is None:
            _log("No saved balances, skipping balances.")
            _say("No saved balances, skipping balances.")
        else:
            _log("Reusing the saved balances.")
            _say("Reusing the saved balances.")
    else:
        ctx.log(f"Reading the Questrade balances in {QUESTRADE_CURRENCY}")
        questrade_balances = read_questrade_balances(
            paths.questrade_token_file,
            force_config_token=questrade_config_token,
        )
        questrade_balance = sum(questrade_balances.values())
        ctx.log(f"Questrade total {format_amount(questrade_balance)}")
        _say(f"Got Questrade balance {format_amount(questrade_balance)}.")
        wise_balance = run_wise_download(ctx, paths, start_date)
        balances = run_download(ctx, paths, start_date)
        balances[Account.WISE] = wise_balance
        save_balances(ctx, balances, questrade_balance)

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
    ctx.log(
        f"Ignored transactions before {start_date.isoformat()}: "
        f"{ignored_count}"
    )
    _say(
        f"Read {len(statement_transactions)} transactions from the statements."
    )

    ctx.log("Recording the decisions")
    decisions = load_decisions(ctx)
    prune_decisions(ctx, decisions)
    transactions = apply_decisions(
        ctx, transactions, decisions, ynab_api_key, start_date
    )
    ctx.log(f"Decided transactions: {len(transactions)} after expansion")

    (
        matched,
        added_count,
        cleared_count,
        deleted_count,
        memo_count,
        sync_count,
    ) = save_to_ynab(
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
            f"{deleted_count} deleted, {memo_count} memos updated"
        )
        if sync_count:
            summary += f", {sync_count} payees and memos synced"
        summary += "."
    record_last_run(ctx, full=not no_download and not no_upload)
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
    except (OSError, ValueError, TypeError) as error:
        ctx.log(f"browser session setup failed: {error}")
        return
    if _BROWSER_OPENED:
        try:
            session_file = ctx.state_path(SESSION_ID)
        except (OSError, TaskError, ValueError, RuntimeError) as error:
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
                    check=False,
                )
                try:
                    os.chmod(session_file, 0o600)
                except OSError as error:
                    ctx.log(f"browser session chmod failed: {error}")
            except (OSError, subprocess.SubprocessError) as error:
                ctx.log(f"browser session save failed: {error}")
    try:
        subprocess.run(
            ["agent-browser", "close"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=30,
            check=False,
        )
    except (OSError, subprocess.SubprocessError) as error:
        ctx.log(f"browser close failed: {error}")


@click.command(
    context_settings={"help_option_names": []}, no_args_is_help=False
)
@click.option("--no-download", is_flag=True, default=False)
@click.option("--no-upload", is_flag=True, default=False)
@click.option("--questrade-config-token", is_flag=True, default=False)
def _budget_sync_options(no_download, no_upload, questrade_config_token):
    # Holds the CLI options. `parse_task_args` runs it without exiting, so
    # its errors raise instead.
    return no_download, no_upload, questrade_config_token


def parse_task_args(args):
    # Returns no-download, no-upload, and questrade-config-token from
    # `args`, the words after the task name, with the same rules as a
    # regular CLI.
    # Telegram replaces `--` with an n-dash or an m-dash, so leading `-`,
    # `–` (U+2013), and `—` (U+2014) all count as `--`.
    normalized = []
    for argument in args:
        if argument.startswith(("-", "–", "—")):
            argument = "--" + argument.lstrip("-–—")
        normalized.append(argument)
    try:
        no_download, no_upload, questrade_config_token = (
            _budget_sync_options.main(normalized, standalone_mode=False)
        )
    except click.ClickException as error:
        raise TaskError(str(error)) from error
    return no_download, no_upload, questrade_config_token


# -----------------------------------------------------------------------------
# Chat helpers.
# -----------------------------------------------------------------------------


def _say(text):
    _CTX.say(text)


def _log(text):
    _CTX.log(text)


def ask_code():
    # Asks for the SMS verification code of the bank. The reply never reaches
    # the log. A timeout stops the task through the bot.
    return _CTX.ask(
        "BMO sent an SMS code. Reply with the digits.",
        pattern=r"\d+",
        timeout=300,
    )


def ask_yes(question, timeout=300):
    # Asks a yes or no question. Returns True for yes.
    answer = _CTX.ask(
        question + " Reply y or n.",
        pattern=r"(?i:yes|y|no|n)",
        timeout=timeout,
    )
    return answer.casefold() in ("y", "yes")


# -----------------------------------------------------------------------------
# Configuration.
# -----------------------------------------------------------------------------


def read_config_text(path):
    # Returns the text at `path` in the configuration. Raises when `jc get`
    # fails, or when the value is missing, `null`, empty, or not text.
    try:
        result = subprocess.run(
            ["jc", "get", path],
            capture_output=True,
            check=False,
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
        raise TaskError(
            f"jc returned invalid JSON for {path}: {error}"
        ) from error
    if value is None or value == "":
        raise TaskError(f"{path} not found in ~/config.json")
    if not isinstance(value, str):
        raise TaskError(f"{path} in ~/config.json is not text")
    return value


# The base of the OpenCode Go inference API for payee suggestions.
OPENCODE_BASE_URL = "https://opencode.ai/inference/go/openai/v1"
# Suggested YNAB payees by bank payee without case, so repeats skip the LLM.
_PAYEE_SUGGESTION_CACHE = {}
# The user agent of the payee suggestion client. OpenCode Go asks each client
# to identify itself with its own name, not with a generic SDK name.
OPENCODE_USER_AGENT = "jpmelos-telegram-budget-sync/1.0"
# The session ID of the current run for OpenCode Go. One ID per run keeps all
# payee questions of the run in one conversation for route and cache use.
_PAYEE_SESSION_ID = None


def payee_session_id():
    # Returns the stable session ID of the current run for OpenCode Go.
    global _PAYEE_SESSION_ID
    if _PAYEE_SESSION_ID is None:
        _PAYEE_SESSION_ID = uuid.uuid4().hex
    return _PAYEE_SESSION_ID


def load_opencode_settings():
    # Returns the API key and the model for payee suggestions, or None pair
    # when the configuration misses them. A miss only skips the LLM, so the
    # run falls back to the manual payee questions.
    try:
        api_key = read_config_text("telegram_bot.opencode.api_key")
    except TaskError as error:
        _log(f"Payee suggestions run without the LLM: {error}")
        return None, None
    try:
        model = read_config_text("telegram_bot.opencode.model")
    except TaskError as error:
        _log(f"Payee suggestions run without the LLM: {error}")
        return None, None
    return api_key, model


def parse_opencode_model(value):
    # Splits `provider/model#effort` into the model ID and the effort level.
    # The provider ends at the first `/`, and the effort follows `#`. The
    # model ID may hold extra `/` parts, but never `#`. Returns empty model
    # with None effort when `value` holds nothing usable.
    text = (value or "").strip()
    effort = None
    if "#" in text:
        text, effort = text.split("#", 1)
        effort = effort.strip() or None
    if "/" in text:
        _, model_id = text.split("/", 1)
        model_id = model_id.strip() or text.strip()
    else:
        model_id = text.strip()
    return model_id, effort


# The JSON schema for the LLM payee suggestions, shared by the Chat
# Completions `response_format` and the Responses `text.format` fields.
PAYEE_MATCHES_SCHEMA = {
    "type": "object",
    "properties": {
        "matches": {
            "type": "array",
            "items": {"type": "string"},
            "minItems": 0,
            "maxItems": 3,
        }
    },
    "required": ["matches"],
    "additionalProperties": False,
}


def build_payee_history(decisions):
    # Returns the past bank to YNAB payee associations in `decisions` as
    # (bank payee, YNAB payee, count) tuples, most frequent first. Singles
    # count once per entry, split parts count once per entry each. The
    # database holds 90 days, so this is the recent history for the LLM.
    counts = collections.Counter()
    for decision in decisions:
        _source, _date_iso, bank_payee, _bank_amount = decision["key"]
        if decision["kind"] == "single":
            counts[(bank_payee, decision["payee"])] += decision["count"]
        else:
            for part in decision["parts"]:
                counts[(bank_payee, part["payee"])] += decision["count"]
    return [
        (bank_payee, payee, count)
        for (bank_payee, payee), count in sorted(
            counts.items(), key=lambda item: (-item[1], item[0][0], item[0][1])
        )
    ]


def suggest_payees_with_llm(
    bank_payee, payee_names, api_key, model, payee_history=None
):
    # Returns up to three YNAB payee names most likely to match `bank_payee`,
    # via the LLM. Returns an empty list on any failure, so the caller falls
    # back to the manual question. `payee_history` holds the past bank to
    # YNAB associations from the transaction database, so the LLM prefers
    # past choices for the same or similar bank payee.
    if not bank_payee or not payee_names or not api_key or not model:
        return []
    cache_key = bank_payee.strip().casefold()
    if cache_key in _PAYEE_SUGGESTION_CACHE:
        return _PAYEE_SUGGESTION_CACHE[cache_key]
    try:
        from openai import OpenAI, OpenAIError
    except ImportError as error:
        _log(f"Payee suggestion lookup skipped: {error}")
        return []
    listed = "\n".join(
        f"- {name}" for name in sorted(payee_names, key=str.casefold)
    )
    if payee_history:
        history_lines = "\n".join(
            f'- Bank "{bank}" -> YNAB "{payee}" ({count}x)'
            for bank, payee, count in payee_history
        )
        prompt = (
            f'Bank payee: "{bank_payee.strip()}"\n'
            f"Existing YNAB payees:\n{listed}\n"
            "Past choices from the last 90 days "
            "(bank payee -> YNAB payee):\n"
            f"{history_lines}\n"
            "Pick the three most likely matches for the bank payee "
            "from the existing list. Prefer past choices for the same or "
            "similar bank payee when relevant.\n"
            'Reply with JSON only, like {"matches": ["Name 1", "Name 2", '
            '"Name 3"]}, with names copied exactly from the list.'
        )
    else:
        prompt = (
            f'Bank payee: "{bank_payee.strip()}"\n'
            f"Existing YNAB payees:\n{listed}\n"
            "Pick the three most likely matches for the bank payee "
            "from the existing list.\n"
            'Reply with JSON only, like {"matches": ["Name 1", "Name 2", '
            '"Name 3"]}, with names copied exactly from the list.'
        )
    try:
        client = OpenAI(
            base_url=OPENCODE_BASE_URL,
            api_key=api_key,
            default_headers={"User-Agent": OPENCODE_USER_AGENT},
        )
        go_headers = {
            "User-Agent": OPENCODE_USER_AGENT,
            "x-opencode-session": payee_session_id(),
        }
        model_id, effort = parse_opencode_model(model)
        if not model_id:
            _log("Payee suggestion lookup skipped: empty model ID")
            return []
        system_text = (
            "You match bank payees to YNAB payees. Reply with JSON only."
        )
        messages = [
            {"role": "system", "content": system_text},
            {"role": "user", "content": prompt},
        ]
        text = ""
        try:
            request = {
                "model": model_id,
                "messages": messages,
                "response_format": {
                    "type": "json_schema",
                    "json_schema": {
                        "name": "payee_matches",
                        "strict": True,
                        "schema": PAYEE_MATCHES_SCHEMA,
                    },
                },
            }
            if effort:
                request["reasoning_effort"] = effort
            try:
                res = client.chat.completions.create(
                    extra_headers=go_headers, **request
                )
            except (
                OpenAIError,
                OSError,
                ValueError,
                TypeError,
                RuntimeError,
            ) as error:
                if not effort:
                    raise
                _log(f"Payee suggestion retry without effort: {error}")
                del request["reasoning_effort"]
                res = client.chat.completions.create(
                    extra_headers=go_headers, **request
                )
            text = res.choices[0].message.content or ""
        except (
            OpenAIError,
            OSError,
            ValueError,
            TypeError,
            RuntimeError,
            AttributeError,
            KeyError,
            IndexError,
        ) as chat_error:
            _log(
                f"Payee suggestion chat failed, trying responses: {chat_error}"
            )
            response_request = {
                "model": model_id,
                "instructions": system_text,
                "input": prompt,
                "text": {
                    "format": {
                        "type": "json_schema",
                        "name": "payee_matches",
                        "strict": True,
                        "schema": PAYEE_MATCHES_SCHEMA,
                    },
                },
            }
            if effort:
                response_request["reasoning"] = {"effort": effort}
            try:
                response = client.responses.create(
                    extra_headers=go_headers, **response_request
                )
            except (
                OpenAIError,
                OSError,
                ValueError,
                TypeError,
                RuntimeError,
            ) as error:
                if not effort:
                    raise
                _log(f"Payee suggestion retry without effort: {error}")
                del response_request["reasoning"]
                response = client.responses.create(
                    extra_headers=go_headers, **response_request
                )
            text = response.output_text or ""
    except (
        OpenAIError,
        OSError,
        ValueError,
        TypeError,
        RuntimeError,
        AttributeError,
        KeyError,
        IndexError,
    ) as error:
        _log(f"Payee suggestion lookup skipped: {error}")
        return []
    matches = parse_payee_suggestions(text, payee_names)
    _PAYEE_SUGGESTION_CACHE[cache_key] = matches
    return matches


def parse_payee_suggestions(text, payee_names):
    # Returns up to three names from `payee_names` in the JSON `text`, or an
    # empty list when the text holds no usable matches. Uses `import json` to
    # parse the `{"matches": [...]}` response of the model.
    try:
        cleaned = text.strip()
        if cleaned.startswith("```"):
            lines = cleaned.splitlines()
            if len(lines) >= 2:
                cleaned = "\n".join(lines[1:])
            end_fence = cleaned.rfind("```")
            if end_fence != -1:
                cleaned = cleaned[:end_fence]
        start = cleaned.find("{")
        end = cleaned.rfind("}")
        if start == -1 or end == -1 or end <= start:
            return []
        data = json.loads(cleaned[start : end + 1])
    except ValueError:
        return []
    if not isinstance(data, dict):
        return []
    raw_matches = data.get("matches")
    if not isinstance(raw_matches, list):
        return []
    by_folded = {}
    for name in payee_names:
        by_folded.setdefault(name.casefold(), name)
    matches = []
    for raw in raw_matches:
        if not isinstance(raw, str) or not raw.strip():
            continue
        cleaned_raw = raw.strip()
        if cleaned_raw in payee_names and cleaned_raw not in matches:
            matches.append(cleaned_raw)
        elif (
            cleaned_raw.casefold() in by_folded
            and by_folded[cleaned_raw.casefold()] not in matches
        ):
            matches.append(by_folded[cleaned_raw.casefold()])
        if len(matches) >= 3:
            break
    return matches


def is_new_payee(payee, payee_names):
    # Returns whether `payee` is not an existing YNAB payee. Transfers are
    # never new. A confirmed name joins `payee_names` at once, so reuse in
    # the same session reports existing and skips confirmation.
    if transfer_target(payee) is not None:
        return False
    if payee_names is None:
        return True
    return payee not in payee_names


def confirm_new_payee(payee):
    # Asks whether to create `payee` as a new YNAB payee. Returns True for yes.
    return ask_yes(f'Create new payee "{payee}"?')


# -----------------------------------------------------------------------------
# State files.
# -----------------------------------------------------------------------------


@dataclass
class SessionPaths:
    # Every path sits in the task state directory. The statements, the Wise
    # cache, the bank session, the Questrade token, the transaction database,
    # and the error screenshot all persist there across runs.
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
        raise TaskError(
            f"cannot prepare the state directory: {error}"
        ) from error
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


def record_last_run(ctx, full=True):
    # Stores when this run finished, so other tasks can check whether a
    # full run happened today. Only runs without flags store, so a run
    # with --no-download or --no-upload leaves the stamp alone. A
    # failure to store only warns, so it never fails a run that already
    # synced.
    if not full:
        return
    stamp = datetime.datetime.now(datetime.UTC).isoformat()
    try:
        ctx.save_state(LAST_RUN_ID, {"last_run": stamp})
    except (OSError, TaskError, ValueError, RuntimeError) as error:
        ctx.log(f"Warning: cannot save {LAST_RUN_ID}: {error}")


# -----------------------------------------------------------------------------
# Steps.
# -----------------------------------------------------------------------------


def run_download(ctx, paths, start_date):
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
        balances = download_statements(
            browser, paths, username, password, start_date
        )
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
            raise TaskError(
                "No downloaded statements. Run without --no-download first"
            )


def download_statements(browser, paths, username, password, start_date):
    # Returns the current balance of each account. See `read_balance`.
    open_login_page(browser, paths)
    accept_cookies(browser)
    log_in(browser, username, password)
    pass_verification(browser)
    chequing_balance = download_chequing_statement(browser, paths, start_date)
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
            f"`agent-browser get count` printed {output.strip()!r}, "
            f"expected a number"
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


def download_chequing_statement(browser, paths, start_date):
    # Returns the current balance of the account. See `read_balance`.
    # Fetches from one day before `start_date` to cover boundary postings.
    _log("Selecting the chequing account")
    browser.find_role("link", "click", "Chequing")
    time.sleep(PAGE_WAIT_SECONDS)
    balance = read_balance(browser, CHEQUING_STATEMENT)
    _say("Opened chequing account.")

    _log("Downloading the chequing account transactions")
    browser.find_role("link", "click", "DOWNLOAD")
    browser.find_role("radio", "click", "Transactions between these dates:")
    to_date = datetime.date.today()
    fetch_from_date = start_date - datetime.timedelta(days=1)
    browser.find_role(
        "textbox", "fill", "From", fetch_from_date.strftime(FORM_DATE_FORMAT)
    )
    browser.find_role(
        "textbox", "fill", "To", to_date.strftime(FORM_DATE_FORMAT)
    )
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
    browser.run(
        "select", 'select[name="period"]', "All Available Transactions"
    )
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
        _log(
            f"Warning: cannot read the current balance "
            f"of the {account_label} page"
        )
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
        raise StepError(
            f"cannot set the mode of the session file: {error}"
        ) from error
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


# -----------------------------------------------------------------------------
# Transactions.
# -----------------------------------------------------------------------------


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
ACCOUNTS_BY_SOURCE = {
    name: account for account, name in SOURCE_BY_ACCOUNT.items()
}


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
    # The memo for YNAB. None means no memo. The chat asks for it with the
    # payee, unless a YNAB offer or a stored decision already holds it.
    memo: str = None
    # The payee name of the bank, as the statement gave it. The decision key
    # uses it, so it never changes.
    bank_payee: str = ""
    # Whether the decision already holds the memo. Older singles without a
    # stored memo still ask for it before the transaction goes to YNAB.
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


CHEQUING_STATEMENT = StatementFormat(
    Account.CHEQUING, date_column="Date Posted"
)
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
                f"a statement row has {len(row)} values, "
                f"expected {len(columns)}"
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
        return datetime.datetime.strptime(
            value.strip(), STATEMENT_DATE_FORMAT
        ).date()
    except ValueError:
        raise TaskError(
            f"invalid date {value.strip()!r} in a statement"
        ) from None


def parse_statement_amount(value):
    try:
        amount = decimal.Decimal(value.strip())
    except decimal.InvalidOperation:
        amount = None
    if amount is None or not amount.is_finite():
        raise TaskError(f"invalid amount {value.strip()!r} in a statement")
    return amount


# -----------------------------------------------------------------------------
# Transaction decisions.
# -----------------------------------------------------------------------------

# A decision row is a dict with a `key` of (source, date ISO, bank payee,
# bank amount), a `count` of bank entries with that key, and either kind
# `single` with a `payee` and a memo, or kind `split` with `parts` of payee,
# amount, and memo. Each row holds its own payee. The task also downloads all
# YNAB payees: the LLM picks three likely matches for each bank payee, and a
# new payee needs confirmation in the chat. A single always holds its memo,
# None for none. A single from before the memo question without a `memo`
# entry still needs its memo from the chat. A part always holds its memo,
# None for none.


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
        raise TaskError(
            f"{what} has a bad date {entry.get('date')!r}"
        ) from None
    bank_payee = entry.get("bank_payee")
    if not isinstance(bank_payee, str) or bank_payee != bank_payee.strip():
        raise TaskError(f"{what} has a bad bank payee")
    if not bank_payee:
        raise TaskError(f"{what} has a bad bank payee")
    bank_amount = parse_decision_amount(
        entry.get("bank_amount"), f"{what} bank amount"
    )
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
        amount = parse_decision_amount(
            raw_part.get("amount"), f"{part_what} amount"
        )
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
    if (
        sum((part["amount"] for part in parts), decimal.Decimal(0))
        != bank_amount
    ):
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


def prune_decisions(ctx, decisions):
    # Removes the rows older than 90 days from `decisions` in place, and
    # saves the database when anything went away.
    cutoff = datetime.date.today() - datetime.timedelta(
        days=DECISION_RETENTION_DAYS
    )
    kept = [
        decision
        for decision in decisions
        if datetime.date.fromisoformat(decision["key"][1]) >= cutoff
    ]
    pruned = len(decisions) - len(kept)
    if not pruned:
        return 0
    decisions[:] = kept
    save_decisions(ctx, decisions)
    ctx.log(f"Pruned {pruned} decision rows older than {cutoff.isoformat()}.")
    ctx.say(f"Pruned {pruned} transactions older than 90 days.")
    return pruned


def transaction_decision_key(transaction):
    # Returns the database key of `transaction`: source, date, bank payee,
    # and bank amount.
    return (
        SOURCE_BY_ACCOUNT[transaction.account],
        transaction.date.isoformat(),
        transaction.bank_payee,
        transaction.amount,
    )


def apply_decisions(
    ctx, transactions, decisions, ynab_api_key=None, start_date=None
):
    # Asks splits first for every undecided group, then matches new entries
    # to YNAB transfers missing a side, then asks payees with transfer
    # matching and LLM suggestions. A split replaces its entry with parts,
    # and parts never split again. A transfer looks for its other end within
    # 7 days and shares one memo. Single-sided transfers go to YNAB in the
    # same run. A new payee needs confirmation. Returns the expanded list.
    lookup = {decision["key"]: decision for decision in decisions}
    groups = {}
    for transaction in sorted(
        transactions, key=lambda item: (item.date, item.amount)
    ):
        groups.setdefault(transaction_decision_key(transaction), []).append(
            transaction
        )
    suggestions, transfer_accounts, payee_names = load_ynab_suggestions(
        ctx, groups, lookup, ynab_api_key, start_date
    )
    opencode_api_key, opencode_model = load_opencode_settings()
    payee_history = build_payee_history(decisions)
    undecided_keys = [key for key in groups if key not in lookup]
    dirty = False
    for key, members in groups.items():
        decision = lookup.get(key)
        if decision is not None and decision["count"] != len(members):
            decision["count"] = len(members)
            dirty = True
    split_amounts_by_key = ask_all_splits(ctx, undecided_keys, groups)
    sides = build_all_sides(groups, lookup, split_amounts_by_key)
    ask_all_transfer_matches(ctx, sides, ynab_api_key, start_date, decisions)
    _paired_ids, updated_keys = ask_all_payees(
        ctx,
        sides,
        groups,
        lookup,
        suggestions,
        transfer_accounts,
        payee_names,
        opencode_api_key,
        opencode_model,
        payee_history,
    )
    new_count = 0
    for key in undecided_keys:
        decision = decision_from_sides(key, sides, groups)
        decision["count"] = len(groups[key])
        decisions.append(decision)
        lookup[key] = decision
        new_count += 1
    if undecided_keys or updated_keys or dirty:
        save_decisions(ctx, decisions)
    remembered_count = len(groups) - len(undecided_keys)
    expanded = []
    for key, members in groups.items():
        for member in members:
            expanded.extend(decision_transactions(lookup[key], member))
    ctx.log(f"decisions: {remembered_count} remembered, {new_count} new")
    _say(f"Decisions done, {new_count} new.")
    return expanded


def ask_all_splits(ctx, undecided_keys, groups):
    # Returns part amounts by group key for undecided groups. Presents the
    # numbered list and asks for splits until none remain. Parts replace
    # their entry and never split again.
    split_amounts = {}
    pending = list(undecided_keys)
    while True:
        if not pending:
            return split_amounts
        display = build_split_display(pending, split_amounts, groups)
        lines = [f"New transactions ({len(display)}):"]
        for index, entry in enumerate(display, start=1):
            lines.append(f"{index}. {entry['text']}")
        _say("\n".join(lines))
        if not ask_yes("Any splits to be made?"):
            return split_amounts
        choice = ask_split_choice(ctx, display)
        entry = display[choice - 1]
        if entry["is_part"]:
            _say("Parts cannot be split again.")
            continue
        key = entry["key"]
        representative = groups[key][0]
        if representative.amount == 0:
            _say("Cannot split a zero amount.")
            continue
        part_count = ask_part_count(ctx)
        amounts = ask_split_amounts(ctx, representative, part_count)
        split_amounts[key] = amounts
        pending.remove(key)


def build_split_display(pending, split_amounts, groups):
    # Returns display entries for pending groups and already split parts.
    display = []
    for key in pending:
        representative = groups[key][0]
        text = decision_line(representative)
        if len(groups[key]) > 1:
            text += f" Applies to {len(groups[key])} identical entries."
        display.append({"text": text, "is_part": False, "key": key})
    for key, amounts in split_amounts.items():
        representative = groups[key][0]
        for part_number, amount in enumerate(amounts, start=1):
            text = (
                f"Part {part_number} of {len(amounts)} for "
                f"{decision_line(representative)}: {format_amount(amount)}"
            )
            display.append(
                {
                    "text": text,
                    "is_part": True,
                    "key": key,
                    "part": part_number - 1,
                }
            )
    return display


def ask_split_choice(ctx, display):
    # Returns the chosen display number. Asks until the reply holds one.
    while True:
        reply = ctx.ask(
            "Which entry to split?\nReply with the number.",
            pattern=r"\d+",
            timeout=300,
        ).strip()
        try:
            choice = int(reply)
        except ValueError:
            continue
        if 1 <= choice <= len(display):
            return choice


def build_all_sides(groups, lookup, split_amounts_by_key):
    # Returns sides by side id for every group. A side id holds the group
    # key with the part index, or None for singles. Remembered sides carry
    # stored payees, and undecided sides still need them.
    sides = {}
    for key, members in groups.items():
        representative = members[0]
        decision = lookup.get(key)
        if decision is not None:
            if decision["kind"] == "single":
                sides[(key, None)] = {
                    "key": key,
                    "part": None,
                    "account": representative.account,
                    "date": representative.date,
                    "amount": representative.amount,
                    "bank_payee": representative.bank_payee,
                    "count": len(members),
                    "payee": decision["payee"],
                    "memo": decision["memo"],
                    "needs_payee": False,
                    "paired_with": None,
                    "is_part": False,
                }
            else:
                for part_index, part in enumerate(decision["parts"]):
                    sides[(key, part_index)] = {
                        "key": key,
                        "part": part_index,
                        "account": representative.account,
                        "date": representative.date,
                        "amount": part["amount"],
                        "bank_payee": representative.bank_payee,
                        "count": len(members),
                        "payee": part["payee"],
                        "memo": part["memo"],
                        "needs_payee": False,
                        "paired_with": None,
                        "is_part": True,
                    }
            continue
        amounts = split_amounts_by_key.get(key)
        if not amounts:
            sides[(key, None)] = {
                "key": key,
                "part": None,
                "account": representative.account,
                "date": representative.date,
                "amount": representative.amount,
                "bank_payee": representative.bank_payee,
                "count": len(members),
                "payee": None,
                "memo": None,
                "needs_payee": True,
                "paired_with": None,
                "is_part": False,
            }
        else:
            for part_index, amount in enumerate(amounts):
                sides[(key, part_index)] = {
                    "key": key,
                    "part": part_index,
                    "account": representative.account,
                    "date": representative.date,
                    "amount": amount,
                    "bank_payee": representative.bank_payee,
                    "count": len(members),
                    "payee": None,
                    "memo": None,
                    "needs_payee": True,
                    "paired_with": None,
                    "is_part": True,
                }
    return sides


def ask_all_payees(
    ctx,
    sides,
    groups,
    lookup,
    suggestions,
    transfer_accounts,
    payee_names=None,
    opencode_api_key=None,
    opencode_model=None,
    payee_history=None,
):
    # Asks payees for sides still needing them, with transfer matching and
    # LLM suggestions. `payee_history` holds the past bank to YNAB
    # associations for the LLM. A confirmed new payee joins `payee_names` at
    # once, so reuse in the same session skips confirmation. Returns paired
    # side ids with updated remembered keys.
    if payee_names is None:
        payee_names = []
    paired_ids = set()
    updated_keys = set()
    ordered = sorted(
        [side_id for side_id, side in sides.items() if side["needs_payee"]],
        key=lambda side_id: (
            sides[side_id]["date"],
            sides[side_id]["amount"],
        ),
    )
    for side_id in ordered:
        if side_id in paired_ids:
            continue
        side = sides[side_id]
        adopted = offer_ynab_for_side(ctx, side, groups, sides, suggestions)
        if adopted is not None:
            side["payee"] = adopted["payee"]
            side["memo"] = adopted["memo"]
            side["needs_payee"] = False
            if is_managed_transfer_side(side):
                match_id = pair_transfer_side(
                    ctx, side_id, sides, paired_ids, groups
                )
                if match_id is not None:
                    paired_ids.add(side_id)
                    paired_ids.add(match_id)
                    updated_keys.update(
                        write_paired_decisions(
                            sides, lookup, side_id, match_id
                        )
                    )
            continue
        payee = ask_payee_for_side(
            ctx,
            side,
            groups,
            transfer_accounts,
            payee_names,
            opencode_api_key,
            opencode_model,
            payee_history,
        )
        side["payee"] = payee
        if not is_managed_transfer_side(side):
            side["memo"] = ask_memo_for_side(side)
            side["needs_payee"] = False
            continue
        match_id = pair_transfer_side(ctx, side_id, sides, paired_ids, groups)
        if match_id is not None:
            paired_ids.add(side_id)
            paired_ids.add(match_id)
            updated_keys.update(
                write_paired_decisions(sides, lookup, side_id, match_id)
            )
        else:
            side["memo"] = ask_memo_for_side(side)
            side["needs_payee"] = False
    return paired_ids, updated_keys


def offer_ynab_for_side(ctx, side, groups, sides, suggestions):
    # Returns an adopted YNAB payee and memo for one side, or None.
    representative = groups[side["key"]][0]
    if side["is_part"]:
        transaction = Transaction(
            date=side["date"],
            amount=side["amount"],
            payee=side["bank_payee"],
            account=side["account"],
            bank_payee=side["bank_payee"],
        )
        part_total = sum(1 for (key, _part) in sides if key == side["key"])
        return ask_part_ynab_offer(
            ctx,
            transaction,
            side["amount"],
            (side["part"] or 0) + 1,
            max(part_total, 2),
            suggestions,
        )
    adopted = ask_ynab_suggestion(
        ctx,
        [representative],
        suggestions_for_transaction(suggestions, representative),
    )
    if adopted is None:
        return None
    return {"payee": adopted["payee"], "memo": adopted["memo"]}


def ask_payee_for_side(
    ctx,
    side,
    groups,
    transfer_accounts,
    payee_names=None,
    opencode_api_key=None,
    opencode_model=None,
    payee_history=None,
):
    # Returns the payee for one side, with LLM suggestions and transfer help.
    # `payee_history` holds the past bank to YNAB associations for the LLM.
    representative = groups[side["key"]][0]
    if side["is_part"]:
        label = (
            f"Part {(side['part'] or 0) + 1} "
            f"for {decision_line(representative)}\n"
            f"Amount {format_amount(side['amount'])}"
        )
        return ask_split_payee(
            ctx,
            label,
            transfer_accounts,
            YNAB_ACCOUNT_NAMES[side["account"]],
            side["bank_payee"],
            payee_names,
            opencode_api_key,
            opencode_model,
            payee_history,
        )
    return ask_single_payee(
        ctx,
        representative,
        side["count"],
        transfer_accounts,
        payee_names,
        opencode_api_key,
        opencode_model,
        payee_history,
    )


def ask_memo_for_side(side):
    # Returns the memo for one side entered alone.
    transaction = Transaction(
        date=side["date"],
        amount=side["amount"],
        payee=side["payee"],
        account=side["account"],
        bank_payee=side["bank_payee"],
    )
    return ask_memo(transaction)


def is_managed_transfer_side(side):
    # Returns whether one side holds a transfer to a managed account.
    if not side.get("payee"):
        return False
    target = transfer_target(side["payee"])
    if target is None:
        return False
    return target in ACCOUNTS_BY_YNAB_NAME


def pair_transfer_side(ctx, side_id, sides, paired_ids, groups):
    # Pairs one managed transfer side with its other end. Returns the match
    # side id, or None when the other end has not appeared yet.
    current = sides[side_id]
    candidates = find_transfer_candidates(side_id, sides, paired_ids)
    if not candidates:
        _say("No possible other ends found.")
        return None
    lines = [f"Possible other ends for {transfer_side_line(current)}:"]
    for index, candidate_id in enumerate(candidates, start=1):
        lines.append(f"{index}. {transfer_side_line(sides[candidate_id])}")
    lines.append("Reply with the number, or n for none.")
    while True:
        reply = ctx.ask(
            "\n".join(lines), pattern=r"(?i:n|\d+)", timeout=300
        ).strip()
        if reply.casefold() == "n":
            return None
        try:
            choice = int(reply)
        except ValueError:
            continue
        if 1 <= choice <= len(candidates):
            match_id = candidates[choice - 1]
            complete_transfer_pair(ctx, side_id, match_id, sides, groups)
            return match_id


def find_transfer_candidates(side_id, sides, paired_ids):
    # Returns candidate side ids for one transfer side. Candidates hold the
    # opposite amount in another account within 7 days, and await pairing.
    current = sides[side_id]
    candidates = []
    for other_id, other in sides.items():
        if other_id == side_id:
            continue
        if other_id in paired_ids or other.get("paired_with"):
            continue
        if other["account"] == current["account"]:
            continue
        if other["amount"] != -current["amount"]:
            continue
        if abs((other["date"] - current["date"]).days) > TRANSFER_MATCH_DAYS:
            continue
        if other.get("payee") is not None:
            if not is_managed_transfer_side(other):
                continue
            if other_id in paired_ids:
                continue
        candidates.append(other_id)
    candidates.sort(
        key=lambda other_id: (
            abs((sides[other_id]["date"] - current["date"]).days),
            sides[other_id]["date"],
            sides[other_id]["account"].value,
            sides[other_id]["bank_payee"],
        )
    )
    return candidates


def transfer_side_line(side):
    # Returns one line for a transfer side in candidate lists.
    text = (
        f"{side['date'].strftime('%m-%d')} "
        f"{ACCOUNT_TAGS[side['account']]} "
        f"{format_amount(side['amount'])} {side['bank_payee']}"
    )
    if side["count"] > 1:
        text += f" Applies to {side['count']} identical entries."
    return text


def complete_transfer_pair(ctx, first_id, second_id, sides, groups):
    # Sets mutual transfer payees from actual accounts and asks one memo.
    first = sides[first_id]
    second = sides[second_id]
    first["payee"] = transfer_payee(YNAB_ACCOUNT_NAMES[second["account"]])
    second["payee"] = transfer_payee(YNAB_ACCOUNT_NAMES[first["account"]])
    first_transaction = Transaction(
        date=first["date"],
        amount=first["amount"],
        payee=first["payee"],
        account=first["account"],
        bank_payee=first["bank_payee"],
    )
    second_transaction = Transaction(
        date=second["date"],
        amount=second["amount"],
        payee=second["payee"],
        account=second["account"],
        bank_payee=second["bank_payee"],
    )
    reply = ctx.ask(
        "Memo for transfer:\n"
        f"{compact_line(first_transaction)}\n"
        f"{compact_line(second_transaction)}\n"
        "Reply with the memo, or - for none.",
        pattern=r"[\s\S]+",
        timeout=300,
    )
    memo = reply.strip()
    shared = None if memo == "-" or not memo else memo
    first["memo"] = shared
    second["memo"] = shared
    first["needs_payee"] = False
    second["needs_payee"] = False
    first["paired_with"] = second_id
    second["paired_with"] = first_id


def write_paired_decisions(sides, lookup, first_id, second_id):
    # Writes paired payees and memos into remembered decisions.
    # Returns remembered group keys that changed.
    changed = set()
    for side_id in (first_id, second_id):
        side = sides[side_id]
        decision = lookup.get(side["key"])
        if decision is None:
            continue
        if side["part"] is None:
            if decision.get("payee") != side["payee"]:
                decision["payee"] = side["payee"]
                changed.add(side["key"])
            if decision.get("memo") != side["memo"]:
                decision["memo"] = side["memo"]
                decision["memo_ready"] = True
                changed.add(side["key"])
        else:
            part = decision["parts"][side["part"]]
            if part["payee"] != side["payee"]:
                part["payee"] = side["payee"]
                changed.add(side["key"])
            if part["memo"] != side["memo"]:
                part["memo"] = side["memo"]
                changed.add(side["key"])
    return changed


def decision_from_sides(key, sides, groups):
    # Returns the new decision row for one undecided group from its sides.
    key_sides = sorted(
        [side for (side_key, _part), side in sides.items() if side_key == key],
        key=lambda side: side["part"] or 0,
    )
    if len(key_sides) == 1 and not key_sides[0]["is_part"]:
        side = key_sides[0]
        return {
            "key": key,
            "count": len(groups[key]),
            "kind": "single",
            "payee": side["payee"],
            "memo": side["memo"],
            "memo_ready": True,
        }
    return {
        "key": key,
        "count": len(groups[key]),
        "kind": "split",
        "parts": [
            {
                "payee": side["payee"],
                "amount": side["amount"],
                "memo": side["memo"],
            }
            for side in key_sides
        ],
    }


def ask_all_transfer_matches(ctx, sides, ynab_api_key, start_date, decisions):
    # Matches new sides to YNAB transfers missing a side. Runs after the
    # split questions, so parts already exist. Sets the payee and the memo
    # from the YNAB transfer, and marks the side as decided. Returns how
    # many sides matched.
    undecided = [
        side_id for side_id, side in sides.items() if side["needs_payee"]
    ]
    if not undecided or ynab_api_key is None or start_date is None:
        return 0
    half_legs = load_ynab_half_legs(ctx, ynab_api_key, start_date, decisions)
    if not half_legs:
        return 0
    matched = 0
    used = set()
    ordered = sorted(
        undecided,
        key=lambda side_id: (sides[side_id]["date"], sides[side_id]["amount"]),
    )
    for side_id in ordered:
        side = sides[side_id]
        if not side["needs_payee"]:
            continue
        try:
            side_milliunits = to_milliunits(side["amount"])
        except TaskError:
            continue
        candidates = []
        for leg_index, leg in enumerate(half_legs):
            if leg_index in used:
                continue
            if leg["account"] != side["account"]:
                continue
            if leg["milliunits"] != side_milliunits:
                continue
            if abs((leg["date"] - side["date"]).days) > TRANSFER_MATCH_DAYS:
                continue
            candidates.append((leg_index, leg))
        if not candidates:
            continue
        candidates.sort(
            key=lambda pair: (
                abs((pair[1]["date"] - side["date"]).days),
                pair[1]["date"],
            )
        )
        choice = ask_transfer_match_choice(
            ctx, side, [leg for _, leg in candidates]
        )
        if choice is None:
            continue
        leg_index, leg = candidates[choice]
        side["payee"] = transfer_payee(
            YNAB_ACCOUNT_NAMES[leg["other_account"]]
        )
        side["memo"] = leg["memo"]
        side["needs_payee"] = False
        used.add(leg_index)
        matched += 1
        _say(
            f"Matched to the YNAB transfer on {leg['date'].strftime('%m-%d')}."
        )
    return matched


def load_ynab_half_legs(ctx, ynab_api_key, start_date, decisions):
    # Returns the YNAB legs missing a side in the database. Each leg holds
    # the account, the date, the amount, the milliunits, the memo, and the
    # other account of the YNAB transfer. Returns an empty list when the
    # fetch fails, so the run continues without matching.
    fetch_start = start_date - datetime.timedelta(days=TRANSFER_MATCH_DAYS)
    pairs = fetch_ynab_managed_pairs(ctx, ynab_api_key, fetch_start)
    if not pairs:
        return []
    return find_half_matched_legs(pairs, decisions)


def fetch_ynab_managed_pairs(ctx, api_key, fetch_start):
    # Returns the YNAB transfer pairs with both legs in managed accounts.
    # Each pair holds ((account, transaction), (account, transaction)).
    # Returns an empty list when the fetch fails.
    try:
        with ynab.ApiClient(
            ynab.Configuration(access_token=api_key)
        ) as api_client:
            plan = load_ynab_plan(api_client)
            by_id = {}
            for account, account_id in plan.account_ids.items():
                response = call_ynab(
                    "read the YNAB transactions",
                    ynab.TransactionsApi(
                        api_client
                    ).get_transactions_by_account,
                    plan.plan_id,
                    str(account_id),
                    since_date=fetch_start,
                )
                for ynab_transaction in response.data.transactions:
                    if ynab_transaction.deleted:
                        continue
                    if ynab_transaction.transfer_account_id is None:
                        continue
                    if ynab_transaction.transfer_transaction_id is None:
                        continue
                    by_id[str(ynab_transaction.id)] = (
                        account,
                        ynab_transaction,
                    )
            seen = set()
            pairs = []
            for txn_id, (account, txn) in by_id.items():
                other_id = str(txn.transfer_transaction_id)
                if other_id not in by_id:
                    continue
                pair_key = tuple(sorted([txn_id, other_id]))
                if pair_key in seen:
                    continue
                seen.add(pair_key)
                other_account, other_txn = by_id[other_id]
                pairs.append(((account, txn), (other_account, other_txn)))
            return pairs
    except (TaskError, OSError, ValueError, RuntimeError) as error:
        ctx.log(f"YNAB transfer match lookup skipped: {error}")
        return []


def find_half_matched_legs(ynab_pairs, decisions):
    # Returns the YNAB legs with no match in the database, where the other
    # leg matches. Each leg holds the account, the date, the amount, the
    # milliunits, the memo, and the other account.
    early_by_ref = decision_transfer_early_dates(decisions)
    expected_counts = collections.Counter()
    for decision in decisions:
        source, date_iso, _bank_payee, bank_amount = decision["key"]
        account = ACCOUNTS_BY_SOURCE[source]
        bank_date = datetime.date.fromisoformat(date_iso)
        if decision["kind"] == "single":
            payees = [(decision["payee"], bank_amount, None)]
        else:
            payees = [
                (part["payee"], part["amount"], part_index)
                for part_index, part in enumerate(decision["parts"])
            ]
        for payee, amount, part_index in payees:
            if transfer_target(payee) not in ACCOUNTS_BY_YNAB_NAME:
                continue
            try:
                milliunits = to_milliunits(amount)
            except TaskError:
                continue
            effective = early_by_ref.get(
                (decision["key"], part_index), bank_date
            )
            key = (
                account,
                effective,
                milliunits,
                canonical_expected_payee(payee),
            )
            expected_counts[key] += decision["count"]
    missing = []
    for (account_a, txn_a), (account_b, txn_b) in ynab_pairs:
        key_a = (
            account_a,
            txn_a.var_date,
            txn_a.amount,
            transfer_payee(YNAB_ACCOUNT_NAMES[account_b]),
        )
        key_b = (
            account_b,
            txn_b.var_date,
            txn_b.amount,
            transfer_payee(YNAB_ACCOUNT_NAMES[account_a]),
        )
        count_a = expected_counts.get(key_a, 0)
        count_b = expected_counts.get(key_b, 0)
        if count_a > 0 and count_b <= 0:
            expected_counts[key_a] -= 1
            missing.append(
                {
                    "account": account_b,
                    "date": txn_b.var_date,
                    "amount": from_milliunits(txn_b.amount),
                    "milliunits": txn_b.amount,
                    "memo": (txn_b.memo or "").strip() or None,
                    "other_account": account_a,
                }
            )
        elif count_b > 0 and count_a <= 0:
            expected_counts[key_b] -= 1
            missing.append(
                {
                    "account": account_a,
                    "date": txn_a.var_date,
                    "amount": from_milliunits(txn_a.amount),
                    "milliunits": txn_a.amount,
                    "memo": (txn_a.memo or "").strip() or None,
                    "other_account": account_b,
                }
            )
        elif count_a > 0 and count_b > 0:
            expected_counts[key_a] -= 1
            expected_counts[key_b] -= 1
    return missing


def half_leg_line(leg):
    # Returns one line for a YNAB leg missing a side in the database.
    return (
        f"{leg['date'].strftime('%m-%d')} "
        f"{ACCOUNT_TAGS[leg['account']]} "
        f"{format_amount(leg['amount'])} memo {display_memo(leg['memo'])} "
        f"other side {ACCOUNT_TAGS[leg['other_account']]}"
    )


def ask_transfer_match_choice(ctx, side, legs):
    # Returns the chosen leg index, or None for no match. A single leg asks
    # yes or no, and several legs ask for a number or n.
    if len(legs) == 1:
        lines = [
            f"New: {transfer_side_line(side)}",
            f"YNAB transfer missing a side: {half_leg_line(legs[0])}",
        ]
        if ask_yes("\n".join(lines) + "\nMatch to this YNAB transfer?"):
            return 0
        return None
    lines = [
        f"New: {transfer_side_line(side)}",
        "YNAB transfers missing a side:",
    ]
    for index, leg in enumerate(legs, start=1):
        lines.append(f"{index}. {half_leg_line(leg)}")
    lines.append("Reply with the number to match, or n for none.")
    while True:
        reply = ctx.ask(
            "\n".join(lines), pattern=r"(?i:n|\d+)", timeout=300
        ).strip()
        if reply.casefold() == "n":
            return None
        try:
            choice = int(reply)
        except ValueError:
            continue
        if 1 <= choice <= len(legs):
            return choice - 1


def find_managed_transfer_pairs(transactions):
    # Returns paired indices with unpaired indices for managed transfers.
    # Two copies pair with mutual payees, opposite amounts, and dates
    # within 7 days. Pairing is greedy by date closeness.
    managed_indices = [
        index
        for index, transaction in enumerate(transactions)
        if is_managed_transfer_transaction(transaction)
    ]
    paired = set()
    pairs = []
    for index in sorted(
        managed_indices,
        key=lambda position: (
            transactions[position].date,
            transactions[position].account.value,
        ),
    ):
        if index in paired:
            continue
        current = transactions[index]
        best = None
        best_diff = None
        for other in managed_indices:
            if other == index or other in paired:
                continue
            candidate = transactions[other]
            if candidate.account == current.account:
                continue
            if candidate.amount != -current.amount:
                continue
            if abs((candidate.date - current.date).days) > TRANSFER_MATCH_DAYS:
                continue
            if not is_mutual_transfer_pair(current, candidate):
                continue
            diff = abs((candidate.date - current.date).days)
            if best is None or diff < best_diff:
                best = other
                best_diff = diff
        if best is not None:
            paired.add(index)
            paired.add(best)
            pairs.append((index, best))
    unpaired = set(managed_indices) - paired
    return pairs, unpaired


def is_managed_transfer_transaction(transaction):
    # Returns whether one transaction holds a transfer to a managed account.
    target = transfer_target(transaction.payee)
    if target is None:
        return False
    return target in ACCOUNTS_BY_YNAB_NAME


def is_mutual_transfer_pair(first, second):
    # Returns whether two transactions point at each other as transfers.
    return (
        transfer_target(first.payee) == YNAB_ACCOUNT_NAMES[second.account]
        and transfer_target(second.payee) == YNAB_ACCOUNT_NAMES[first.account]
    )


def transfer_early_dates(transactions):
    # Returns the YNAB date by index for paired managed transfers.
    # YNAB keeps both legs on one date, so both legs use the earliest bank
    # date of the pair. Unpaired entries are not here.
    pairs, _unpaired = find_managed_transfer_pairs(transactions)
    early_by_index = {}
    for first_index, second_index in pairs:
        early = min(
            transactions[first_index].date, transactions[second_index].date
        )
        early_by_index[first_index] = early
        early_by_index[second_index] = early
    return early_by_index


def decision_transfer_early_dates(decisions):
    # Returns the YNAB date by decision reference for paired managed
    # transfers. The reference holds the decision key with the part index,
    # or None for singles. Both sides of a pair share the earliest bank
    # date, which is the date that YNAB holds. Unpaired entries are absent.
    legs = []
    for decision in decisions:
        source, date_iso, _bank_payee, bank_amount = decision["key"]
        account = ACCOUNTS_BY_SOURCE[source]
        bank_date = datetime.date.fromisoformat(date_iso)
        if decision["kind"] == "single":
            payee = decision["payee"]
            if transfer_target(payee) in ACCOUNTS_BY_YNAB_NAME:
                legs.append(
                    {
                        "account": account,
                        "date": bank_date,
                        "amount": bank_amount,
                        "payee": payee,
                        "ref": (decision["key"], None),
                    }
                )
        else:
            for part_index, part in enumerate(decision["parts"]):
                payee = part["payee"]
                if transfer_target(payee) in ACCOUNTS_BY_YNAB_NAME:
                    legs.append(
                        {
                            "account": account,
                            "date": bank_date,
                            "amount": part["amount"],
                            "payee": payee,
                            "ref": (decision["key"], part_index),
                        }
                    )
    synthetic = [
        Transaction(
            date=leg["date"],
            amount=leg["amount"],
            payee=leg["payee"],
            account=leg["account"],
        )
        for leg in legs
    ]
    pairs, _unpaired = find_managed_transfer_pairs(synthetic)
    early_by_ref = {}
    for first_index, second_index in pairs:
        early = min(synthetic[first_index].date, synthetic[second_index].date)
        early_by_ref[legs[first_index]["ref"]] = early
        early_by_ref[legs[second_index]["ref"]] = early
    return early_by_ref


def find_transfer_date_corrections(transactions, comparison, plan):
    # Returns YNAB transfer pairs that need a date move to the earliest bank
    # date of the matching bank pair. YNAB keeps both legs on one date, so a
    # pair dated after the early leg still refers to the same two bank
    # entries. Each correction holds the YNAB legs, the current YNAB date,
    # and the early date. Only managed pairs with both legs visible qualify.
    expected_pairs, _unpaired = find_managed_transfer_pairs(transactions)
    if not expected_pairs:
        return []
    by_id = {}
    for account in YNAB_ACCOUNT_NAMES:
        for txns in comparison.ynab_by_key_by_account.get(
            account, {}
        ).values():
            for txn in txns:
                by_id[str(txn.id)] = (account, txn)
    seen_pair_keys = set()
    actual_pairs = []
    for account, txn in by_id.values():
        if (
            txn.transfer_account_id is None
            or txn.transfer_transaction_id is None
        ):
            continue
        other_name = plan.account_names.get(
            txn.transfer_account_id, str(txn.transfer_account_id)
        )
        if other_name not in ACCOUNTS_BY_YNAB_NAME:
            continue
        other_id = str(txn.transfer_transaction_id)
        if other_id not in by_id:
            continue
        pair_key = tuple(sorted([str(txn.id), other_id]))
        if pair_key in seen_pair_keys:
            continue
        seen_pair_keys.add(pair_key)
        other_account, other_txn = by_id[other_id]
        if other_txn.transfer_account_id is None:
            continue
        actual_pairs.append(((account, txn), (other_account, other_txn)))
    corrections = []
    used_actual = set()
    for first_index, second_index in expected_pairs:
        first = transactions[first_index]
        second = transactions[second_index]
        early = min(first.date, second.date)
        expected_legs = {
            (
                first.account,
                to_milliunits(first.amount),
                canonical_expected_payee(first.payee),
            ),
            (
                second.account,
                to_milliunits(second.amount),
                canonical_expected_payee(second.payee),
            ),
        }
        best = None
        best_diff = None
        best_key = None
        for pair_index, ((account_a, txn_a), (account_b, txn_b)) in enumerate(
            actual_pairs
        ):
            if pair_index in used_actual:
                continue
            try:
                actual_legs = {
                    (
                        account_a,
                        txn_a.amount,
                        canonical_expected_payee(
                            transfer_payee(
                                plan.account_names.get(
                                    txn_a.transfer_account_id,
                                    str(txn_a.transfer_account_id),
                                )
                            )
                        ),
                    ),
                    (
                        account_b,
                        txn_b.amount,
                        canonical_expected_payee(
                            transfer_payee(
                                plan.account_names.get(
                                    txn_b.transfer_account_id,
                                    str(txn_b.transfer_account_id),
                                )
                            )
                        ),
                    ),
                }
            except TaskError:
                continue
            if actual_legs != expected_legs:
                continue
            current = txn_a.var_date
            if txn_b.var_date != current:
                current = min(current, txn_b.var_date)
            if current == early:
                best = None
                best_key = None
                break
            if abs((current - early).days) > TRANSFER_MATCH_DAYS:
                continue
            diff = abs((current - early).days)
            if best is None or diff < best_diff:
                best = ((account_a, txn_a), (account_b, txn_b), current)
                best_diff = diff
                best_key = pair_index
        if best is None:
            continue
        (_account_a, txn_a), (_account_b, txn_b), current = best
        used_actual.add(best_key)
        corrections.append(
            {
                "txns": [txn_a, txn_b],
                "current": current,
                "early": early,
                "label": (
                    f"{early.strftime('%m-%d')} Transfer "
                    f"{ACCOUNT_TAGS[_account_a]} <-> "
                    f"{ACCOUNT_TAGS[_account_b]} "
                    f"{format_amount(from_milliunits(txn_a.amount))}"
                ),
            }
        )
    return corrections


def apply_transfer_date_corrections(plan, corrections):
    # Moves each YNAB transfer pair in `corrections` to its early date.
    # Moving one leg moves the other leg with it, but both legs update to
    # the same date for safety. Preserves clearing and approval by only
    # sending the identifier and the date.
    updates = []
    for correction in corrections:
        for txn in correction["txns"]:
            updates.append(
                ynab.SaveTransactionWithIdOrImportId(
                    id=txn.id, var_date=correction["early"]
                )
            )
    try:
        ynab.TransactionsApi(plan.api_client).update_transactions(
            plan.plan_id, ynab.PatchTransactionsWrapper(transactions=updates)
        )
    except YNAB_ERRORS as error:
        raise TaskError(
            f"cannot move the transfer dates in YNAB: {error}"
        ) from error


def suggestion_key(transaction):
    # Returns the YNAB lookup key of `transaction`: account, date, and amount
    # in milliunits. Returns None when the amount cannot go to YNAB, so the
    # group gets no offer.
    try:
        milliunits = to_milliunits(transaction.amount)
    except TaskError:
        return None
    return (transaction.account, transaction.date, milliunits)


def suggestions_for_transaction(suggestions, transaction):
    # Returns YNAB payee and memo offers for `transaction`: exact matches on
    # account, date, and amount, plus nearby managed transfers on the same
    # account and amount within 7 days. YNAB keeps both legs of a transfer
    # on the earliest bank date, so the later bank leg still finds the
    # transfer offer dated on the early leg.
    key = suggestion_key(transaction)
    if key is None:
        return None
    found = list(suggestions.get(key, []))
    try:
        milliunits = to_milliunits(transaction.amount)
    except TaskError:
        return found or None
    for (account, date, amount), entries in suggestions.items():
        if account != transaction.account or amount != milliunits:
            continue
        if date == transaction.date:
            continue
        if abs((date - transaction.date).days) > TRANSFER_MATCH_DAYS:
            continue
        for entry in entries:
            if transfer_target(entry["payee"]) not in ACCOUNTS_BY_YNAB_NAME:
                continue
            if (entry["payee"], entry["memo"]) not in {
                (item["payee"], item["memo"]) for item in found
            }:
                found.append(entry)
    return found or None


def part_suggestions_for_amount(suggestions, transaction, amount):
    # Returns YNAB offers for one split part amount: exact matches plus
    # nearby managed transfers, like `suggestions_for_transaction`.
    probe = Transaction(
        date=transaction.date,
        amount=amount,
        payee=transaction.payee,
        account=transaction.account,
        bank_payee=transaction.bank_payee,
    )
    return suggestions_for_transaction(suggestions, probe)


def load_ynab_suggestions(ctx, groups, lookup, ynab_api_key, start_date):
    # Returns the YNAB payee and memo offers by suggestion key, with the
    # sorted transfer account names and all YNAB payee names, for the groups
    # without a stored decision. Fetches YNAB once. Returns empty values when
    # nothing is undecided, when the caller gives no API key or start date,
    # or when the fetch fails, so the run falls back to the manual questions.
    undecided = any(key not in lookup for key in groups)
    if not undecided or ynab_api_key is None or start_date is None:
        return {}, [], []
    ctx.log("Checking YNAB for payee suggestions")
    try:
        return fetch_ynab_suggestions(ynab_api_key, start_date)
    except (TaskError, OSError, ValueError, RuntimeError) as error:
        ctx.log(f"YNAB suggestion lookup skipped: {error}")
        return {}, [], []


def fetch_ynab_suggestions(api_key, start_date):
    # Returns the distinct YNAB payee and memo pairs by suggestion key, with
    # the sorted transfer account names and all YNAB payee names, from the
    # transactions since `start_date`. Skips deleted transactions and ones
    # without a usable payee. Transfer payees use the canonical
    # `Transfer: <account name>` form, so an adopted payee matches
    # `statement_key` later.
    suggestions = {}
    with ynab.ApiClient(
        ynab.Configuration(access_token=api_key)
    ) as api_client:
        plan = load_ynab_plan(api_client)
        for account, account_id in plan.account_ids.items():
            response = call_ynab(
                "read the YNAB transactions",
                ynab.TransactionsApi(api_client).get_transactions_by_account,
                plan.plan_id,
                str(account_id),
                since_date=start_date,
            )
            for ynab_transaction in response.data.transactions:
                if ynab_transaction.deleted:
                    continue
                if ynab_transaction.transfer_account_id is not None:
                    payee = transfer_payee(
                        plan.account_names.get(
                            ynab_transaction.transfer_account_id,
                            str(ynab_transaction.transfer_account_id),
                        )
                    )
                else:
                    payee = ynab_transaction.payee_name or ""
                    if not payee.strip():
                        continue
                    if len(payee) > YNAB_PAYEE_NAME_LIMIT:
                        continue
                memo = (ynab_transaction.memo or "").strip() or None
                key = (
                    account,
                    ynab_transaction.var_date,
                    ynab_transaction.amount,
                )
                entries = suggestions.setdefault(key, [])
                if (payee, memo) not in {
                    (entry["payee"], entry["memo"]) for entry in entries
                }:
                    entries.append({"payee": payee, "memo": memo})
        transfer_accounts = sorted(plan.transfer_payee_ids, key=str.casefold)
        payee_names = sorted(
            {
                name
                for names in plan.payees.names_by_folded_name.values()
                for name in names
            },
            key=str.casefold,
        )
    return suggestions, transfer_accounts, payee_names


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


def ask_decision(
    ctx,
    members,
    suggestions=None,
    all_suggestions=None,
    transfer_accounts=None,
    payee_names=None,
    opencode_api_key=None,
    opencode_model=None,
    payee_history=None,
):
    # Asks how one group of identical bank entries splits, and returns the
    # new decision row. `members` holds the entries. `suggestions` holds the
    # YNAB payee and memo offers for the whole entry, if any. An accepted
    # offer becomes a single decision with its memo stored, so nothing else
    # asks. A declined offer stays in the regular pool: the group asks whether
    # to split like any other group, then asks for the payee and the memo.
    # The parts then look themselves up in `all_suggestions` by account, date,
    # and amount. `transfer_accounts` holds the sorted YNAB account names for
    # the transfer menu. `payee_names` holds all YNAB payees for the LLM
    # suggestions and the new payee confirmation. `payee_history` holds the
    # past bank to YNAB associations for the LLM.
    adopted = ask_ynab_suggestion(ctx, members, suggestions)
    if adopted is not None:
        return adopted
    representative = members[0]
    lines = [decision_line(representative)]
    if len(members) > 1:
        lines.append(f"Applies to {len(members)} identical entries.")
    if ask_yes("\n".join(lines) + "\nSplit this entry?"):
        return ask_split_decision(
            ctx,
            representative,
            len(members),
            all_suggestions or {},
            transfer_accounts,
            payee_names,
            opencode_api_key,
            opencode_model,
            payee_history,
        )
    payee = ask_single_payee(
        ctx,
        representative,
        len(members),
        transfer_accounts,
        payee_names,
        opencode_api_key,
        opencode_model,
        payee_history,
    )
    memo = ask_memo(
        Transaction(
            date=representative.date,
            amount=representative.amount,
            payee=payee,
            account=representative.account,
            bank_payee=representative.bank_payee,
        )
    )
    return {
        "key": transaction_decision_key(representative),
        "count": len(members),
        "kind": "single",
        "payee": payee,
        "memo": memo,
        "memo_ready": True,
    }


def ask_ynab_suggestion(ctx, members, suggestions):
    # Returns a single decision row from a YNAB offer that the chat accepts,
    # or None when there is no offer or the chat declines. The memo always
    # stores, so no later question asks for it.
    if not suggestions:
        return None
    if len(suggestions) > 1:
        return ask_ynab_choice(ctx, members, suggestions)
    offer = suggestions[0]
    representative = members[0]
    lines = [decision_line(representative)]
    if len(members) > 1:
        lines.append(f"Applies to {len(members)} identical entries.")
    lines.append(
        f'YNAB has payee "{offer["payee"]}" '
        f"memo {display_memo(offer['memo'])}."
    )
    if ask_yes("\n".join(lines) + "\nTake payee and memo from YNAB?"):
        return {
            "key": transaction_decision_key(representative),
            "count": len(members),
            "kind": "single",
            "payee": offer["payee"],
            "memo": offer["memo"],
            "memo_ready": True,
        }
    return None


def ask_ynab_choice(ctx, members, suggestions):
    # Returns a single decision row from one of several YNAB offers, or None
    # when the chat declines them all.
    representative = members[0]
    lines = [decision_line(representative)]
    if len(members) > 1:
        lines.append(f"Applies to {len(members)} identical entries.")
    lines.append("YNAB has:")
    for index, offer in enumerate(suggestions, start=1):
        lines.append(
            f'{index}. payee "{offer["payee"]}" '
            f"memo {display_memo(offer['memo'])}"
        )
    lines.append("Reply with the number to take, or n for none.")
    while True:
        reply = ctx.ask(
            "\n".join(lines), pattern=r"(?i:n|\d+)", timeout=300
        ).strip()
        if reply.casefold() == "n":
            return None
        try:
            choice = int(reply)
        except ValueError:
            continue
        if 1 <= choice <= len(suggestions):
            offer = suggestions[choice - 1]
            return {
                "key": transaction_decision_key(representative),
                "count": len(members),
                "kind": "single",
                "payee": offer["payee"],
                "memo": offer["memo"],
                "memo_ready": True,
            }


def decision_line(transaction):
    # One line with the full bank payee, for the decision questions.
    return (
        f"{transaction.date.strftime('%m-%d')} "
        f"{ACCOUNT_TAGS[transaction.account]} "
        f"{format_amount(transaction.amount)} {transaction.bank_payee}"
    )


def resolve_typed_payee(
    ctx, typed, transfer_accounts=None, excluded_account=None
):
    # Returns the YNAB payee for `typed`, with transfer help. A lone `t`
    # means a transfer. A `Transfer:` prefix with an empty, unknown, or
    # excluded account shows the account menu. A valid transfer returns in
    # canonical `Transfer: <account name>` form. Any other name returns as
    # typed. Needs `transfer_target` and `transfer_payee`, which the YNAB
    # section defines. Without account names, every name returns as typed.
    # Returns None when no other account exists for a transfer, so the
    # caller asks for the payee again.
    if not transfer_accounts:
        return typed.strip()
    cleaned = typed.strip()
    if cleaned.casefold() == "t":
        return ask_transfer_account(
            ctx, transfer_accounts, excluded_account=excluded_account
        )
    target = transfer_target(cleaned)
    if target is not None:
        if target in transfer_accounts and target != excluded_account:
            return transfer_payee(target)
        return ask_transfer_account(
            ctx, transfer_accounts, target, excluded_account=excluded_account
        )
    if cleaned.casefold().startswith("transfer:"):
        _, _, after = cleaned.partition(":")
        candidate = after.strip()
        if candidate in transfer_accounts and candidate != excluded_account:
            return transfer_payee(candidate)
        return ask_transfer_account(
            ctx,
            transfer_accounts,
            candidate or None,
            excluded_account=excluded_account,
        )
    return cleaned


def ask_transfer_account(
    ctx, account_names, attempted=None, excluded_account=None
):
    # Returns the canonical `Transfer: <account name>` payee for the YNAB
    # account chosen by number. `account_names` holds the open YNAB accounts.
    # The menu sorts alphabetically and leaves out `excluded_account`, the
    # account of the current transaction, since a transfer needs another
    # account. `attempted` holds the unknown name for the message, or None
    # for the `t` shortcut and empty names. Returns None when no other
    # account exists, so the caller asks for the payee again.
    ordered = sorted(
        (name for name in account_names if name != excluded_account),
        key=str.casefold,
    )
    if not ordered:
        _say(
            "No other YNAB account exists for a transfer. Use a regular payee."
        )
        return None
    lines = []
    if attempted is not None and attempted == excluded_account:
        lines.append(
            f'A transfer to "{attempted}" is not possible. '
            "Choose the other account:"
        )
    elif attempted:
        lines.append(
            f'No YNAB account named "{attempted}". '
            "Choose the transfer account:"
        )
    else:
        lines.append("Choose the transfer account:")
    for index, name in enumerate(ordered, start=1):
        lines.append(f"{index}. {name}")
    lines.append("Reply with the number.")
    prompt = "\n".join(lines)
    while True:
        reply = ctx.ask(prompt, pattern=r"\d+", timeout=300).strip()
        try:
            choice = int(reply)
        except ValueError:
            continue
        if 1 <= choice <= len(ordered):
            return transfer_payee(ordered[choice - 1])


def ask_single_payee(
    ctx,
    transaction,
    count,
    transfer_accounts=None,
    payee_names=None,
    opencode_api_key=None,
    opencode_model=None,
    payee_history=None,
):
    # Returns the YNAB payee for one undecided bank entry. Sends the bank
    # payee with all YNAB payees and the past bank to YNAB associations to
    # the LLM, shows three likely matches as a numbered list, and takes a
    # number or a typed name. A lone `t` or a `Transfer:` prefix with an
    # empty or unknown account shows the transfer menu and returns the
    # canonical `Transfer: <account name>` form. The menu leaves out the
    # account of the entry itself. A new payee needs confirmation before the
    # task uses it, then joins the YNAB payee list at once, so reuse in the
    # same session skips confirmation.
    excluded_account = YNAB_ACCOUNT_NAMES[transaction.account]
    matches = suggest_payees_with_llm(
        transaction.bank_payee,
        payee_names or [],
        opencode_api_key,
        opencode_model,
        payee_history,
    )
    base_lines = ["Payee:", decision_line(transaction)]
    if count > 1:
        base_lines.append(f"Applies to {count} identical entries.")
    if matches:
        base_lines.append(f'Bank payee "{transaction.bank_payee}" matches:')
        for index, name in enumerate(matches, start=1):
            base_lines.append(f"{index}. {name}")
        base_lines.append(
            "Reply with the number, the name to use, or t for a transfer."
        )
    else:
        base_lines.append("Reply with the name to use, or t for a transfer.")
    prompt = "\n".join(base_lines)
    while True:
        reply = ctx.ask(prompt, pattern=r"[\s\S]+", timeout=600).strip()
        if not reply:
            continue
        if matches and re.fullmatch(r"\d+", reply):
            try:
                choice = int(reply)
            except ValueError:
                continue
            if 1 <= choice <= len(matches):
                return matches[choice - 1]
            continue
        if len(reply) > YNAB_PAYEE_NAME_LIMIT:
            _say(
                f"That name is over the YNAB payee limit "
                f"of {YNAB_PAYEE_NAME_LIMIT}."
            )
            continue
        resolved = resolve_typed_payee(
            ctx, reply, transfer_accounts, excluded_account
        )
        if resolved is None:
            continue
        if len(resolved) > YNAB_PAYEE_NAME_LIMIT:
            _say(
                f"That name is over the YNAB payee limit "
                f"of {YNAB_PAYEE_NAME_LIMIT}."
            )
            continue
        if is_new_payee(resolved, payee_names):
            if not confirm_new_payee(resolved):
                continue
            if payee_names is not None:
                payee_names.append(resolved)
        return resolved


def ask_split_decision(
    ctx,
    transaction,
    count,
    suggestions,
    transfer_accounts=None,
    payee_names=None,
    opencode_api_key=None,
    opencode_model=None,
    payee_history=None,
):
    # Returns the split decision row for one group of identical bank entries.
    # Asks only for the part amounts first: the amounts of each part but the
    # last, then the remainder as the last amount, confirmed in the chat. A
    # rejected remainder restarts the amounts from the first, with the same
    # count, since an earlier amount holds the mistake. Each part amount then
    # looks itself up in YNAB by account, date, and amount: an accepted offer
    # takes the YNAB payee and memo with nothing else to ask, and any other
    # part asks for its payee and memo with LLM help. A new payee needs
    # confirmation.
    if transaction.amount == 0:
        raise TaskError("cannot split a zero amount")
    key = transaction_decision_key(transaction)
    part_count = ask_part_count(ctx)
    amounts = ask_split_amounts(ctx, transaction, part_count)
    parts = [
        resolve_split_part(
            ctx,
            transaction,
            amount,
            part_number,
            part_count,
            suggestions,
            transfer_accounts,
            payee_names,
            opencode_api_key,
            opencode_model,
            payee_history,
        )
        for part_number, amount in enumerate(amounts, start=1)
    ]
    return {
        "key": key,
        "count": count,
        "kind": "split",
        "parts": parts,
    }


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


def ask_split_payee(
    ctx,
    label,
    transfer_accounts=None,
    excluded_account=None,
    bank_payee=None,
    payee_names=None,
    opencode_api_key=None,
    opencode_model=None,
    payee_history=None,
):
    # Returns the YNAB payee for one split part. Sends the bank payee with
    # all YNAB payees and the past bank to YNAB associations to the LLM,
    # shows three likely matches as a numbered list, and takes a number or a
    # typed name. A lone `t` or a `Transfer:` prefix with an empty or unknown
    # account shows the transfer menu and returns the canonical
    # `Transfer: <account name>` form. The menu leaves out `excluded_account`,
    # the account of the current transaction. A new payee needs confirmation
    # before the task uses it, then joins the YNAB payee list at once, so
    # reuse in the same session skips confirmation.
    matches = suggest_payees_with_llm(
        bank_payee or "",
        payee_names or [],
        opencode_api_key,
        opencode_model,
        payee_history,
    )
    if matches:
        numbered = "\n".join(
            f"{index}. {name}" for index, name in enumerate(matches, start=1)
        )
        prompt = (
            f"{label}\n"
            f'Bank payee "{(bank_payee or "").strip()}" matches:\n'
            f"{numbered}\n"
            "Reply with the number, the payee, or t for a transfer."
        )
    else:
        prompt = f"{label}\nReply with the payee, or t for a transfer."
    while True:
        reply = ctx.ask(prompt, pattern=r"[\s\S]+", timeout=600).strip()
        if not reply:
            continue
        if matches and re.fullmatch(r"\d+", reply):
            try:
                choice = int(reply)
            except ValueError:
                continue
            if 1 <= choice <= len(matches):
                return matches[choice - 1]
            continue
        if len(reply) > YNAB_PAYEE_NAME_LIMIT:
            _say(
                f"That name is over the YNAB payee limit "
                f"of {YNAB_PAYEE_NAME_LIMIT}."
            )
            continue
        resolved = resolve_typed_payee(
            ctx, reply, transfer_accounts, excluded_account
        )
        if resolved is None:
            continue
        if len(resolved) > YNAB_PAYEE_NAME_LIMIT:
            _say(
                f"That name is over the YNAB payee limit "
                f"of {YNAB_PAYEE_NAME_LIMIT}."
            )
            continue
        if is_new_payee(resolved, payee_names):
            if not confirm_new_payee(resolved):
                continue
            if payee_names is not None:
                payee_names.append(resolved)
        return resolved


def ask_split_amounts(ctx, transaction, part_count):
    # Returns the amounts of a split: the typed amounts of each part but the
    # last, plus the remainder as the last amount. Restarts from the first
    # part when the remainder cannot work or the chat rejects it.
    while True:
        amounts = [
            ask_split_amount(ctx, transaction, part_number, part_count)
            for part_number in range(1, part_count)
        ]
        entered = sum(amounts, decimal.Decimal(0))
        remaining = transaction.amount - entered
        label = (
            f"Part {part_count} of {part_count} "
            f"for {decision_line(transaction)}"
        )
        if remaining == 0 or (remaining > 0) != (transaction.amount > 0):
            _say(
                f"Parts so far add to {format_amount(entered)}, "
                f"leaving {format_amount(remaining)}. Start over from part 1."
            )
            continue
        if not ask_yes(
            f"{label}\nCalculated amount {format_amount(remaining)}. "
            "Is that right?"
        ):
            _say("Start over from part 1.")
            continue
        return [*amounts, remaining]


def ask_split_amount(ctx, transaction, part_number, part_count):
    # Returns the typed amount of one split part. Asks until the reply holds
    # a nonzero amount with the sign of the whole entry.
    label = (
        f"Part {part_number} of {part_count} for {decision_line(transaction)}"
    )
    while True:
        reply = ctx.ask(
            f"{label}\nReply with the signed amount "
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
        return amount


def part_suggestion_key(transaction, amount):
    # Returns the YNAB lookup key of one split part amount: account, date, and
    # amount in milliunits. Returns None when the amount cannot go to YNAB,
    # so the part gets no offer.
    try:
        milliunits = to_milliunits(amount)
    except TaskError:
        return None
    return (transaction.account, transaction.date, milliunits)


def resolve_split_part(
    ctx,
    transaction,
    amount,
    part_number,
    part_count,
    suggestions,
    transfer_accounts=None,
    payee_names=None,
    opencode_api_key=None,
    opencode_model=None,
    payee_history=None,
):
    # Returns one split part with its payee, amount, and memo. A YNAB
    # transaction with the same account, date, and amount offers its payee
    # and memo first. An accepted offer becomes the part with nothing else to
    # ask. Any other part asks for its payee and memo with LLM help. A new
    # payee needs confirmation.
    adopted = ask_part_ynab_offer(
        ctx, transaction, amount, part_number, part_count, suggestions
    )
    if adopted is not None:
        return {
            "payee": adopted["payee"],
            "amount": amount,
            "memo": adopted["memo"],
        }
    label = (
        f"Part {part_number} of {part_count} "
        f"for {decision_line(transaction)}\n"
        f"Amount {format_amount(amount)}"
    )
    payee = ask_split_payee(
        ctx,
        label,
        transfer_accounts,
        YNAB_ACCOUNT_NAMES[transaction.account],
        transaction.bank_payee,
        payee_names,
        opencode_api_key,
        opencode_model,
        payee_history,
    )
    memo = ask_memo(
        Transaction(
            date=transaction.date,
            amount=amount,
            payee=payee,
            account=transaction.account,
        )
    )
    return {"payee": payee, "amount": amount, "memo": memo}


def ask_part_ynab_offer(
    ctx, transaction, amount, part_number, part_count, suggestions
):
    # Returns the payee and memo of a YNAB offer for one split part amount
    # that the chat accepts, or None when there is no offer or the chat
    # declines. `suggestions` maps YNAB lookup keys to payee and memo offers.
    # Nearby managed transfers within 7 days also offer, since YNAB keeps
    # both legs on the earliest bank date.
    offers = part_suggestions_for_amount(suggestions, transaction, amount)
    if not offers:
        return None
    if len(offers) > 1:
        return ask_part_ynab_choice(
            ctx, transaction, amount, part_number, part_count, offers
        )
    offer = offers[0]
    lines = [
        part_line(transaction, amount, part_number, part_count),
        (
            f'YNAB has payee "{offer["payee"]}" '
            f"memo {display_memo(offer['memo'])}."
        ),
    ]
    if ask_yes("\n".join(lines) + "\nTake payee and memo from YNAB?"):
        return {"payee": offer["payee"], "memo": offer["memo"]}
    return None


def ask_part_ynab_choice(
    ctx, transaction, amount, part_number, part_count, offers
):
    # Returns the payee and memo of one of several YNAB offers for a split
    # part amount, or None when the chat declines them all.
    lines = [
        part_line(transaction, amount, part_number, part_count),
        "YNAB has:",
    ]
    for index, offer in enumerate(offers, start=1):
        lines.append(
            f'{index}. payee "{offer["payee"]}" '
            f"memo {display_memo(offer['memo'])}"
        )
    lines.append("Reply with the number to take, or n for none.")
    while True:
        reply = ctx.ask(
            "\n".join(lines), pattern=r"(?i:n|\d+)", timeout=300
        ).strip()
        if reply.casefold() == "n":
            return None
        try:
            choice = int(reply)
        except ValueError:
            continue
        if 1 <= choice <= len(offers):
            offer = offers[choice - 1]
            return {"payee": offer["payee"], "memo": offer["memo"]}


def part_line(transaction, amount, part_number, part_count):
    # One short line with the part number and amount, for the split questions.
    return (
        f"Part {part_number} of {part_count} "
        f"for {decision_line(transaction)}: "
        f"{format_amount(amount)}"
    )


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


# -----------------------------------------------------------------------------
# Narrow chat report.
# -----------------------------------------------------------------------------


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
    # One line for a narrow screen: date, account tag, amount, full payee.
    return (
        f"{transaction.date.strftime('%m-%d')} "
        f"{ACCOUNT_TAGS[transaction.account]} "
        f"{format_amount(transaction.amount)} {transaction.payee}"
    )


def say_new_transactions(transactions):
    # Reports only the transactions that YNAB does not have yet.
    if not transactions:
        _say("No new transactions.")
        return
    lines = [f"New ({len(transactions)}):"]
    for transaction in sorted(transactions, key=report_order)[
        :REPORT_LINE_LIMIT
    ]:
        lines.append(compact_line(transaction))
    if len(transactions) > REPORT_LINE_LIMIT:
        lines.append(f"+{len(transactions) - REPORT_LINE_LIMIT} more")
    _say("\n".join(lines))


# -----------------------------------------------------------------------------
# Questrade.
# -----------------------------------------------------------------------------

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


def read_questrade_balances(token_path, force_config_token=False):
    # Returns the balance of each Questrade account in `QUESTRADE_CURRENCY`,
    # rounded to cents, by the type and the number of the account. When
    # `force_config_token` holds, the saved token is skipped and the
    # config token is used.
    session = start_questrade_session(
        token_path, force_config_token=force_config_token
    )
    accounts = questrade_get(
        session, "accounts", "read the Questrade accounts"
    )
    accounts = accounts.get("accounts")
    if not isinstance(accounts, list) or not accounts:
        raise TaskError("Questrade returned no accounts")

    balances = {}
    for account in accounts:
        number = account.get("number") if isinstance(account, dict) else None
        # The number goes into the URL of the next call.
        if not isinstance(number, str) or not number.isdigit():
            raise TaskError(
                f"Questrade returned an account with the number {number!r}"
            )
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
                f"Questrade returned a bad total equity for "
                f"account {account_number}"
            )
        return decimal.Decimal(total_equity).quantize(CENT)
    raise TaskError(
        f"Questrade returned no combined balance in {QUESTRADE_CURRENCY} for "
        f"account {account_number}"
    )


def start_questrade_session(token_path, force_config_token=False):
    # Returns a session with a new access token. Questrade accepts each
    # refresh token once, and returns a new one with the access token. The
    # new refresh token goes to `token_path` before any other call, so that
    # the next run can use it. The refresh token that `jc` reads serves only
    # when `token_path` holds no token, when Questrade rejects that token,
    # or when `force_config_token` skips the saved token.
    response = None
    if force_config_token:
        _log("Skipping the saved Questrade token by request.")
    else:
        saved_token = read_questrade_token(token_path)
        if saved_token is None:
            _log(
                "No saved Questrade token. "
                "The task uses `jc get questrade.api_key`."
            )
        else:
            response = redeem_questrade_token(saved_token)
            if response is None:
                _log(
                    "Warning: Questrade rejected the saved refresh token. "
                    "The task uses `jc get questrade.api_key`."
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
    if not isinstance(api_server, str) or not api_server.startswith(
        "https://"
    ):
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
        raise TaskError(
            f"cannot {action}: {describe_questrade_failure(response)}"
        )
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
        raise TaskError(
            f"cannot {action}: {describe_questrade_failure(response)}"
        )
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


# -----------------------------------------------------------------------------
# Wise.
# -----------------------------------------------------------------------------

# The base of the Wise Platform API. The balance calls use `/v4` and the
# profile and statement calls use `/v1`, as in the Wise docs.
WISE_API_BASE = "https://api.wise.com"
WISE_TIMEOUT_SECONDS = 30
# Only this currency syncs to YNAB. The YNAB account holds one currency, and
# Wise holds each currency in a balance of its own. Transactions and the
# balance come from the CAD STANDARD balance, the chequing account. SAVINGS
# balances, the jars, and other currencies stay out. That balance maps to the
# "Wise Chequing" account in YNAB. The profile and the balance come from
# `wise.profile_id` and `wise.balance_id` in the configuration, as strings.
WISE_CURRENCY = "CAD"


def run_wise_download(ctx, paths, start_date):
    # Fetches the Wise transactions and balance through the API, saves the
    # transactions to the Wise cache, and returns the balance. Same role as
    # `run_download` for BMO, but without a browser. Fetches from one day
    # before `start_date` to cover boundary postings.
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
    fetch_from_date = start_date - datetime.timedelta(days=1)
    transactions, balance = fetch_wise_data(
        api_token, profile_id, balance_id, fetch_from_date, to_date
    )
    save_wise_transactions(paths.wise_file, transactions)
    ctx.log(
        f"Wise transactions: {len(transactions)}, "
        f"balance {format_amount(balance)}"
    )
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
        raise TaskError(
            f"{path} in ~/config.json is not a numeric ID"
        ) from None
    if value <= 0:
        raise TaskError(f"{path} in ~/config.json is not a numeric ID")
    return value


def fetch_wise_data(api_token, profile_id, balance_id, from_date, to_date):
    # Returns the transactions between `from_date` and `to_date` and the
    # current balance of the configured chequing account. That account maps
    # to the "Wise Chequing" account in YNAB.
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
        wise_to_transaction(item)
        for item in statement_transactions_of(statement)
    ]
    return transactions, balance


def wise_get_balance(api_token, profile_id, balance_id):
    # Returns one Wise balance, with its current amounts.
    return wise_get(
        f"read the Wise balance {balance_id}",
        f"{WISE_API_BASE}/v4/profiles/{profile_id}/balances/{balance_id}",
        api_token,
    )


def wise_get_statement(
    api_token, profile_id, balance_id, interval_start, interval_end
):
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
        amount = wise_amount_value(
            record.get(key), f"Wise balance field {key}"
        )
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
    # Returns the bank payee name of one Wise statement item. The transaction
    # database replaces it with the payee of the user, same as for BMO.
    # Prefers the human description, then the merchant name, then the sender
    # name.
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
            raise TaskError(
                f"the Wise cache holds a bad amount {raw_amount!r}"
            )
        if not amount.is_finite():
            raise TaskError(
                f"the Wise cache holds a bad amount {raw_amount!r}"
            )
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


def save_balances(ctx, balances, questrade_balance):
    # Writes the bank and Questrade balances to the cache, so
    # `--no-download` still sends them to YNAB. Amounts keep their
    # exact value as strings, and `None` stays `None`.
    raw_balances = {}
    for account, amount in balances.items():
        source = SOURCE_BY_ACCOUNT[account]
        if amount is None:
            raw_balances[source] = None
        else:
            raw_balances[source] = str(amount)
    if questrade_balance is None:
        raw_questrade = None
    else:
        raw_questrade = str(questrade_balance)
    data = {
        "balances": raw_balances,
        "questrade_balance": raw_questrade,
    }
    try:
        ctx.save_state(BALANCES_ID, data)
    except (OSError, TypeError, ValueError) as error:
        raise TaskError(f"cannot save {BALANCES_ID}: {error}") from error


def load_balances(ctx):
    # Returns the cached bank balances and Questrade balance, or
    # `(None, None)` when no cache exists yet. Raises when the cache
    # holds bad data, so bad data never reaches YNAB silently.
    raw = ctx.load_state(BALANCES_ID)
    if raw is None:
        return None, None
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as error:
        raise TaskError(f"cannot read {BALANCES_ID}: {error}") from error
    try:
        data = json.loads(text)
    except ValueError as error:
        raise TaskError(f"cannot read {BALANCES_ID}: {error}") from error
    if not isinstance(data, dict):
        raise TaskError(f"{BALANCES_ID} holds no balance object")
    raw_balances = data.get("balances")
    if not isinstance(raw_balances, dict):
        raise TaskError(f"{BALANCES_ID} holds no balances")
    balances = {}
    for source, account in ACCOUNTS_BY_SOURCE.items():
        value = raw_balances.get(source)
        if value is None:
            balances[account] = None
        else:
            balances[account] = parse_decision_amount(
                value, f"{BALANCES_ID} {source}"
            )
    raw_questrade = data.get("questrade_balance")
    if raw_questrade is None:
        questrade_balance = None
    else:
        questrade_balance = parse_decision_amount(
            raw_questrade, f"{BALANCES_ID} questrade"
        )
    return balances, questrade_balance


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
        raise TaskError(
            f"cannot {action}: Wise returned no JSON object or list"
        )
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


# -----------------------------------------------------------------------------
# YNAB.
# -----------------------------------------------------------------------------

# The YNAB account of each statement.
YNAB_ACCOUNT_NAMES = {
    Account.CHEQUING: "BMO Chequing",
    Account.CREDIT_CARD: "BMO MasterCard",
    Account.WISE: "Wise Chequing",
}
ACCOUNTS_BY_YNAB_NAME = {
    name: account for account, name in YNAB_ACCOUNT_NAMES.items()
}
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
    ctx,
    transactions,
    decisions,
    start_date,
    bank_balances,
    questrade_balance,
    api_key,
    upload,
):
    # Brings YNAB up to date with the statements, then compares the cleared
    # balances with `bank_balances`, then brings the YNAB account of
    # Questrade to `questrade_balance`. Pre-reads the YNAB cleared balances of
    # each managed account before any write when `bank_balances` exists,
    # passes the pre-reads with the statement deltas to `report_balances` so
    # the YNAB sides hold this run's writes, and reports again after a
    # Questrade add so the final message holds all writes. Returns whether
    # YNAB matches the statements, with the counts of added, cleared,
    # deleted, memo-updated, and synced transactions. Because of
    # `--no-download`, `bank_balances` and `questrade_balance` can be `None`,
    # and the step of each one does not run. Without `upload`, the task reads
    # YNAB and reports the changes, but writes nothing to YNAB.
    with ynab.ApiClient(
        ynab.Configuration(access_token=api_key)
    ) as api_client:
        plan = load_ynab_plan(api_client)
        if bank_balances is None:
            pre_balances = None
        else:
            pre_balances = {
                account: from_milliunits(
                    read_ynab_account(
                        plan, plan.account_ids[account]
                    ).cleared_balance
                )
                for account in YNAB_ACCOUNT_NAMES
            }
        (
            matched,
            added_count,
            cleared_count,
            deleted_count,
            memo_count,
            sync_count,
            deltas,
        ) = update_from_statements(
            ctx, plan, transactions, decisions, start_date, upload
        )
        questrade_state = report_balances(
            plan,
            bank_balances,
            questrade_balance,
            matched,
            pre_balances,
            deltas,
        )
        if questrade_state is not None:
            questrade_added = reconcile_questrade(
                plan,
                questrade_balance,
                matched,
                upload,
                difference=questrade_state[0],
                ynab_balance=questrade_state[1],
            )
            if questrade_added:
                report_balances(
                    plan,
                    bank_balances,
                    questrade_balance,
                    matched,
                    pre_balances,
                    deltas,
                )
    return (
        matched,
        added_count,
        cleared_count,
        deleted_count,
        memo_count,
        sync_count,
    )


def report_balances(
    plan,
    bank_balances,
    questrade_balance,
    ynab_matches_statements,
    pre_balances=None,
    deltas=None,
):
    # Sends the bank and Questrade balances in one message, then returns the
    # Questrade difference and YNAB balance for `reconcile_questrade`, or
    # None when Questrade is skipped. The YNAB sides hold this run's statement
    # writes: `pre_balances` with `deltas` go to `build_bank_balance_lines`,
    # which shows expected on a stale read. The caller reports again after a
    # Questrade add, so the final message holds everything.
    if bank_balances is None:
        bank_block = "Bank balances skipped."
        bank_differences = 0
    else:
        bank_lines, bank_differences = build_bank_balance_lines(
            plan, bank_balances, pre_balances, deltas
        )
        bank_block = "Bank / YNAB:\n" + "\n".join(bank_lines)
    if questrade_balance is None:
        questrade_block = "Questrade skipped."
        questrade_state = None
    else:
        questrade_line, questrade_difference, questrade_ynab_balance = (
            build_questrade_balance_line(plan, questrade_balance)
        )
        questrade_block = questrade_line
        questrade_state = (questrade_difference, questrade_ynab_balance)
    message = bank_block + "\n" + questrade_block
    if (
        bank_balances is not None
        and bank_differences
        and not ynab_matches_statements
    ):
        message += "\nPending changes can cause the diffs."
    _say(message)
    _log(f"bank balance differences: {bank_differences}")
    return questrade_state


def update_from_statements(
    ctx, plan, transactions, decisions, start_date, upload
):
    # Syncs the recognized YNAB transactions with the database, then adds to
    # YNAB the statement transactions that it does not have, clears the YNAB
    # transactions that match a statement transaction but are not cleared,
    # and deletes the surplus YNAB copies of bank entries. The only deletions
    # in the task happen here. Leaves the YNAB transactions that no statement
    # holds as they are. Every read and check happens before the first change
    # of each phase, and a problem stops the task before any change of that
    # phase. Without `upload`, the task reads YNAB and reports the changes,
    # but writes nothing to YNAB. Returns whether YNAB matches the statements
    # at the end, with the counts of added, cleared, deleted, memo-updated,
    # and synced transactions, plus the cleared-balance deltas by account from
    # the final comparison used for writes: added sums the missing statement
    # amounts, cleared sums the uncleared YNAB amounts moved to cleared, and
    # deleted subtracts the cleared victim amounts. Paths that write nothing
    # return zero deltas for every account in `YNAB_ACCOUNT_NAMES`.
    comparison = compare_with_ynab(plan, transactions, start_date)
    date_corrections = find_transfer_date_corrections(
        transactions, comparison, plan
    )
    if date_corrections:
        lines = [f"Move transfers to earliest date ({len(date_corrections)}):"]
        for correction in date_corrections[:REPORT_LINE_LIMIT]:
            lines.append(
                f"{correction['current'].strftime('%m-%d')} -> "
                f"{correction['early'].strftime('%m-%d')} "
                f"{correction['label']}"
            )
        if len(date_corrections) > REPORT_LINE_LIMIT:
            lines.append(f"+{len(date_corrections) - REPORT_LINE_LIMIT} more")
        _say("\n".join(lines))
        if not upload:
            _say("Preview only. YNAB unchanged.")
            report_memo_count(comparison, start_date)
            return (
                False,
                0,
                0,
                0,
                0,
                0,
                {
                    account: decimal.Decimal(0)
                    for account in YNAB_ACCOUNT_NAMES
                },
            )
        if not ask_yes(
            f"In YNAB, move {len(date_corrections)} transfer(s) "
            "to earliest dates?"
        ):
            _say("Cancelled. YNAB unchanged.")
            report_memo_count(comparison, start_date)
            return (
                False,
                0,
                0,
                0,
                0,
                0,
                {
                    account: decimal.Decimal(0)
                    for account in YNAB_ACCOUNT_NAMES
                },
            )
        apply_transfer_date_corrections(plan, date_corrections)
        _say(f"Moved {len(date_corrections)} transfer(s) to earliest dates.")
        comparison = compare_with_ynab(plan, transactions, start_date)
    report_ignored_counts(comparison)
    transactions_to_send, problems, transfer_early_dates = plan_additions(
        plan, comparison.missing_transactions
    )
    if problems:
        _say("Blocked:\n" + "\n".join(problems))
        _say("Fix the names in YNAB or in `transactions.json` and rerun.")
        report_memo_count(comparison, start_date)
        raise TaskError("YNAB unchanged. Fix and rerun.")
    victims_by_account = deletable_transactions(comparison)
    doomed_ids = {
        victim.id
        for victims in victims_by_account.values()
        for victim in victims
    }
    # Syncs the recognized payees and memos first. Entries with the same
    # account, date, and amount compare as multisets, so the add/delete flow
    # below never sees a mere payee or memo edit as missing plus extra.
    sync_mismatches, transfer_pairs = find_sync_mismatches(
        expected_sync_groups(decisions, start_date),
        actual_sync_groups(comparison, start_date, doomed_ids),
    )
    sync_pushes, sync_adopted = resolve_sync_mismatches(
        ctx, plan, decisions, transactions, sync_mismatches, transfer_pairs
    )
    sync_count = 0
    if sync_pushes or sync_adopted:
        if sync_pushes:
            say_sync_updates(sync_pushes)
        if not upload:
            _say("Preview only. YNAB unchanged.")
            report_memo_count(comparison, start_date)
            return (
                False,
                0,
                0,
                0,
                0,
                0,
                {
                    account: decimal.Decimal(0)
                    for account in YNAB_ACCOUNT_NAMES
                },
            )
        if sync_pushes:
            if not ask_yes(
                f"In YNAB, update {len(sync_pushes)} payees and memos?"
            ):
                _say("Cancelled. YNAB unchanged.")
                report_memo_count(comparison, start_date)
                return (
                    False,
                    0,
                    0,
                    0,
                    0,
                    0,
                    {
                        account: decimal.Decimal(0)
                        for account in YNAB_ACCOUNT_NAMES
                    },
                )
            update_ynab_payees_memos(plan, sync_pushes)
            sync_count = len(sync_pushes)
            _say(f"Updated {sync_count} payees and memos.")
            if any(item["transfer_change"] for item in sync_pushes):
                _say("A transfer changed. Check the other side.")
        # The sync changes keys, so the plan below starts from fresh state.
        comparison = compare_with_ynab(plan, transactions, start_date)
        transactions_to_send, problems, transfer_early_dates = plan_additions(
            plan, comparison.missing_transactions
        )
        if problems:
            _say("Blocked:\n" + "\n".join(problems))
            _say("Fix the names in YNAB or in `transactions.json` and rerun.")
            report_memo_count(comparison, start_date)
            if sync_count:
                raise TaskError(
                    f"YNAB updated with {sync_count} payees and memos, but "
                    "blocked on the rest. Fix and rerun."
                )
            raise TaskError("YNAB unchanged. Fix and rerun.")
        victims_by_account = deletable_transactions(comparison)
        doomed_ids = {
            victim.id
            for victims in victims_by_account.values()
            for victim in victims
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
    if (
        not missing_count
        and not uncleared_count
        and not delete_count
        and not memo_count
    ):
        _say("YNAB already matches.")
        report_memo_count(comparison, start_date)
        return (
            True,
            0,
            0,
            0,
            0,
            sync_count,
            {account: decimal.Decimal(0) for account in YNAB_ACCOUNT_NAMES},
        )

    if missing_count:
        say_new_transactions(comparison.missing_transactions)
        transfers = [
            transaction
            for transaction in transactions_to_send
            if transfer_target(transaction.payee) is not None
        ]
        if transfers:
            _say(
                f"{len(transfers)} transfer(s). YNAB adds each other side by "
                "itself on the earliest date."
            )
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
        return (
            False,
            0,
            0,
            0,
            0,
            sync_count,
            {account: decimal.Decimal(0) for account in YNAB_ACCOUNT_NAMES},
        )
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
        if sync_count:
            _say(
                f"Cancelled the rest. "
                f"YNAB keeps {sync_count} payees and memos."
            )
        else:
            _say("Cancelled. YNAB unchanged.")
        report_memo_count(comparison, start_date)
        return (
            False,
            0,
            0,
            0,
            0,
            sync_count,
            {account: decimal.Decimal(0) for account in YNAB_ACCOUNT_NAMES},
        )

    if missing_count:
        send_transactions(
            ctx, plan, transactions_to_send, decisions, transfer_early_dates
        )
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
    # it already held outside the statements and the other sides that YNAB
    # added for single-sided transfers. The other sides start uncleared, so
    # paired ones, which match statements, get cleared here before the final
    # check, while single-sided ones stay uncleared as extra.
    allowed_new_keys = expected_auto_created_keys(
        transactions, transactions_to_send, transfer_early_dates
    )
    result = compare_with_ynab(plan, transactions, start_date)
    if (
        not result.missing_transactions
        and result.uncleared_transactions
        and not remaining_extra_keys(
            result, comparison, deleted_keys_by_account, allowed_new_keys
        )
    ):
        clear_ynab_transactions(plan, result.uncleared_transactions)
        result = compare_with_ynab(plan, transactions, start_date)
    if (
        result.missing_transactions
        or result.uncleared_transactions
        or remaining_extra_keys(
            result, comparison, deleted_keys_by_account, allowed_new_keys
        )
    ):
        log_ynab_differences(result)
        _say("YNAB still differs. Check YNAB.")
        report_memo_count(result, start_date)
        raise TaskError("YNAB differs after the changes.")
    if sync_count:
        synced_part = f", synced {sync_count} payees and memos"
    else:
        synced_part = ""
    _say(
        f"Added {missing_count}, cleared {uncleared_count}, "
        f"deleted {delete_count}, updated {memo_count} memos{synced_part}."
    )
    report_memo_count(result, start_date)
    deltas = {account: decimal.Decimal(0) for account in YNAB_ACCOUNT_NAMES}
    for transaction in comparison.missing_transactions:
        deltas[transaction.account] += transaction.amount
    for ynab_transaction in comparison.uncleared_transactions:
        cleared_account = ACCOUNTS_BY_YNAB_NAME.get(
            getattr(ynab_transaction, "account_name", None)
        )
        if cleared_account is not None:
            deltas[cleared_account] += from_milliunits(ynab_transaction.amount)
    for account, victims in victims_by_account.items():
        for victim in victims:
            if victim.cleared != ynab.TransactionClearedStatus.UNCLEARED:
                deltas[account] -= from_milliunits(victim.amount)
    return (
        True,
        missing_count,
        uncleared_count,
        delete_count,
        memo_count,
        sync_count,
        deltas,
    )


def remaining_extra_keys(
    result,
    comparison,
    deleted_keys_by_account,
    allowed_new_keys_by_account=None,
):
    # Returns whether `result` holds extra YNAB keys beyond the expected
    # ones. Expected ones live outside the statements, come from deletions,
    # or come from the other sides that YNAB added for single-sided
    # transfers. Compares each account as a multiset.
    for account in YNAB_ACCOUNT_NAMES:
        expected = collections.Counter(
            comparison.extra_keys_by_account.get(account, [])
        )
        expected.subtract(
            collections.Counter(deleted_keys_by_account.get(account, []))
        )
        if allowed_new_keys_by_account:
            expected.update(
                collections.Counter(
                    allowed_new_keys_by_account.get(account, [])
                )
            )
        if (
            collections.Counter(result.extra_keys_by_account.get(account, []))
            != expected
        ):
            return True
    return False


def expected_auto_created_keys(
    transactions, sent_transactions, early_dates_by_id
):
    # Returns the YNAB keys of the other sides that YNAB adds by itself for
    # single-sided managed transfers, by account. Paired transfers already
    # expect both sides. Transfers to accounts without a statement add their
    # other side outside the managed accounts, so only unpaired managed
    # transfers appear here.
    allowed = {account: [] for account in YNAB_ACCOUNT_NAMES}
    pairs, _unpaired = find_managed_transfer_pairs(transactions)
    paired_ids = set()
    for first_index, second_index in pairs:
        paired_ids.add(id(transactions[first_index]))
        paired_ids.add(id(transactions[second_index]))
    for sent in sent_transactions:
        if id(sent) in paired_ids:
            continue
        target_name = transfer_target(sent.payee)
        if target_name is None:
            continue
        target_account = ACCOUNTS_BY_YNAB_NAME.get(target_name)
        if target_account is None:
            continue
        try:
            other_milliunits = -to_milliunits(sent.amount)
        except TaskError:
            continue
        ynab_date = (early_dates_by_id or {}).get(id(sent), sent.date)
        allowed[target_account].append(
            (
                ynab_date,
                transfer_payee(YNAB_ACCOUNT_NAMES[sent.account]),
                other_milliunits,
            )
        )
    return allowed


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
                key=lambda item: (
                    item.cleared != ynab.TransactionClearedStatus.UNCLEARED
                ),
            )
            victims.extend(ordered[:count])
        transfer_victims = [
            victim
            for victim in victims
            if victim.transfer_account_id is not None
        ]
        if transfer_victims:
            lines = [
                describe_ynab_transaction(victim)
                for victim in transfer_victims
            ]
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
        lines.append(
            f"{victim.var_date.strftime('%m-%d')} "
            f"{format_amount(from_milliunits(victim.amount))} {payee}"
        )
    if len(victims) > REPORT_LINE_LIMIT:
        lines.append(f"+{len(victims) - REPORT_LINE_LIMIT} more")
    _say("\n".join(lines))


def build_bank_balance_lines(
    plan, bank_balances, pre_balances=None, deltas=None
):
    # Returns one short line per account with the balance at the bank and the
    # cleared balance in YNAB, with how many of them differ.
    # `bank_balances` maps each account to its balance at the bank, or to
    # `None` when the task could not read it. `pre_balances` holds the YNAB
    # cleared balances from before this run wrote, and `deltas` holds this
    # run's cleared-balance changes by account, so expected holds pre plus
    # delta. A fresh read follows, and when it differs from expected the task
    # logs a warning and shows expected, which holds this run's writes by
    # construction, else it shows the fresh read. The line format and the DIFF
    # count stay the same.
    lines = []
    differences = 0
    for account, ynab_name in YNAB_ACCOUNT_NAMES.items():
        tag = ACCOUNT_TAGS[account]
        ynab_account = read_ynab_account(plan, plan.account_ids[account])
        fresh_balance = from_milliunits(ynab_account.cleared_balance)
        ynab_balance = fresh_balance
        if pre_balances is not None and deltas is not None:
            pre = (
                pre_balances.get(account)
                if isinstance(pre_balances, dict)
                else None
            )
            delta = deltas.get(account) if isinstance(deltas, dict) else None
            if pre is not None and delta is not None:
                expected = pre + delta
                if fresh_balance != expected:
                    _log(
                        f"Warning: YNAB cleared balance for {ynab_name} "
                        f"reads {format_amount(fresh_balance)} but expected "
                        f"{format_amount(expected)} with this run's writes. "
                        "Showing expected."
                    )
                    ynab_balance = expected
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
    return lines, differences


def build_questrade_balance_line(plan, questrade_balance):
    # Returns the balance line of Questrade with the difference to the cleared
    # YNAB balance and the cleared YNAB balance, so the combined report can
    # reuse them without reading YNAB twice.
    ynab_account = read_ynab_account(plan, plan.questrade_account_id)
    ynab_balance = from_milliunits(ynab_account.cleared_balance)
    difference = questrade_balance - ynab_balance
    mark = "OK" if difference == 0 else "DIFF"
    line = (
        f"QT {format_amount(questrade_balance)} "
        f"/ {format_amount(ynab_balance)} {mark}"
    )
    return line, difference, ynab_balance


def reconcile_questrade(
    plan,
    questrade_balance,
    ynab_matches_statements,
    upload,
    difference=None,
    ynab_balance=None,
):
    # Adds a transaction to the YNAB account of Questrade that brings its
    # cleared balance to `questrade_balance`. The cleared YNAB balance leaves
    # out uncleared transactions, so it matches what the bank reports. The
    # transaction waits until YNAB matches the statements, which
    # `ynab_matches_statements` tells. Without `upload`, the task reports the
    # difference, but changes nothing. The balance goes to YNAB only once a
    # day: when the account already has a reconciliation transaction dated
    # today, the task reports the difference, but changes nothing. The
    # combined balances message already reported the balances, so this only
    # sends the follow-ups. `difference` and `ynab_balance` reuse the values
    # from that report; when missing, this reads YNAB again. Returns True when
    # it adds the reconciliation transaction, else False.
    if difference is None or ynab_balance is None:
        ynab_account = read_ynab_account(plan, plan.questrade_account_id)
        ynab_balance = from_milliunits(ynab_account.cleared_balance)
        difference = questrade_balance - ynab_balance

    if difference == 0:
        _say("Questrade already matches.")
        return False
    if not upload:
        _say("Preview only. YNAB unchanged.")
        return False
    if not ynab_matches_statements:
        _say("Skipped: YNAB missed the statement changes.")
        return False
    if questrade_reconciled_today(plan):
        _say("Skipped: Questrade already reconciled today.")
        return False
    if not ask_yes(f"Add QT {format_amount(difference)}?"):
        _say("Cancelled. YNAB unchanged.")
        return False

    send_reconciliation(plan, difference)
    ynab_account = read_ynab_account(plan, plan.questrade_account_id)
    new_balance = from_milliunits(ynab_account.cleared_balance)
    if new_balance != questrade_balance:
        _say("QT differs after the change. Check YNAB.")
        raise TaskError("Questrade differs after the reconciliation.")
    _say(f"QT {format_amount(difference)} added.")
    return True


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
    plans = call_ynab(
        "read the YNAB plans", ynab.PlansApi(api_client).get_plans
    )
    plans = plans.data.plans
    if len(plans) != 1:
        plan_names = ", ".join(plan.name for plan in plans) or "none"
        raise TaskError(
            f"expected one YNAB plan, found {len(plans)}: {plan_names}"
        )
    plan_id = str(plans[0].id)

    accounts = call_ynab(
        "read the YNAB accounts",
        ynab.AccountsApi(api_client).get_accounts,
        plan_id,
    )
    accounts = [
        account for account in accounts.data.accounts if not account.deleted
    ]
    account_ids = {
        account: find_open_account_id(accounts, account_name)
        for account, account_name in YNAB_ACCOUNT_NAMES.items()
    }
    questrade_account_id = find_open_account_id(
        accounts, QUESTRADE_YNAB_ACCOUNT_NAME
    )

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
                payee.name: payee.id
                for payee in payees
                if name_counts[payee.name] == 1
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
    # Paired managed transfers use one YNAB date for both legs: the
    # earliest bank date of the pair. The map holds that date by object,
    # so each leg compares on the YNAB date while reports keep bank dates.
    early_by_index = transfer_early_dates(transactions)
    early_by_id = {
        id(transaction): early_by_index[index]
        for index, transaction in enumerate(transactions)
        if index in early_by_index
    }
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
        missing, extra_keys, uncleared, expected_keys, ynab_by_key = (
            compare_account(
                plan,
                statement_transactions,
                visible_transactions,
                early_by_id,
            )
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


def compare_account(
    plan, statement_transactions, ynab_transactions, early_by_id=None
):
    # Returns the statement transactions that YNAB does not have, the keys of
    # the YNAB transactions that the statement does not have, the YNAB
    # transactions that match a statement transaction but are not cleared,
    # the keys that the statements expect, and the YNAB transactions by key.
    # Each key counts as many times as it appears, so two equal transactions
    # on a date need two in YNAB. Paired managed transfers compare on the
    # earliest bank date of the pair, which is the single date that YNAB
    # holds, while the returned statement objects keep their bank dates.
    def effective_key(transaction):
        early = None
        if early_by_id is not None:
            early = early_by_id.get(id(transaction))
        return statement_key(transaction, early)

    statement_counts = collections.Counter(
        map(effective_key, statement_transactions)
    )
    ynab_keys = [
        ynab_key(plan, ynab_transaction)
        for ynab_transaction in ynab_transactions
    ]
    ynab_counts = collections.Counter(ynab_keys)
    ynab_by_key = collections.defaultdict(list)
    for key, ynab_transaction in zip(ynab_keys, ynab_transactions):
        ynab_by_key[key].append(ynab_transaction)

    missing_counts = statement_counts - ynab_counts
    missing_transactions = []
    for transaction in statement_transactions:
        key = effective_key(transaction)
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
        key=lambda pair: (
            pair[1].cleared == ynab.TransactionClearedStatus.UNCLEARED
        ),
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


def statement_key(transaction, effective_date=None):
    # The date, the payee, and the amount in milliunits. The payee of a
    # transfer is `Transfer: <account name>`, whatever its spacing in the
    # decision. `effective_date` overrides the bank date: paired managed
    # transfers use the earliest bank date of the pair, which is the single
    # date that YNAB holds for both legs.
    target_name = transfer_target(transaction.payee)
    payee = (
        transaction.payee
        if target_name is None
        else transfer_payee(target_name)
    )
    date = effective_date if effective_date is not None else transaction.date
    return (date, payee, to_milliunits(transaction.amount))


def ynab_key(plan, ynab_transaction):
    # The key of a YNAB transaction, in the form of `statement_key`. YNAB
    # names transfer payees in a format of its own, so the payee of a
    # transfer comes from the account at the other side.
    transfer_account_id = ynab_transaction.transfer_account_id
    if transfer_account_id is None:
        payee = ynab_transaction.payee_name or ""
    else:
        payee = transfer_payee(
            plan.account_names.get(
                transfer_account_id, str(transfer_account_id)
            )
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
    # Returns the transactions to send, problems, and YNAB dates for
    # cross-day transfers. YNAB adds the other side by itself, so only one
    # side goes per managed pair, on the earliest bank date of the pair,
    # since YNAB keeps both legs on one date. Pairs allow dates within 7
    # days with mutual payees. Single-sided managed transfers go on their
    # bank date. A transfer to an account without a statement has only the
    # one side, on its bank date.
    transactions_to_send = []
    problems = []
    early_dates_by_id = {}
    managed_candidates = []
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
        if (
            target_name == own_name
            or target_name not in plan.transfer_payee_ids
        ):
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
        managed_candidates.append(transaction)
    if managed_candidates:
        pairs, _unpaired = find_managed_transfer_pairs(managed_candidates)
        paired_indices = {index for pair in pairs for index in pair}
        for first_index, second_index in pairs:
            first = managed_candidates[first_index]
            second = managed_candidates[second_index]
            if (second.date, second.account.value) < (
                first.date,
                first.account.value,
            ):
                sent = second
            else:
                sent = first
            transactions_to_send.append(sent)
            early = min(first.date, second.date)
            if sent.date != early:
                early_dates_by_id[id(sent)] = early
        for index, transaction in enumerate(managed_candidates):
            if index not in paired_indices:
                transactions_to_send.append(transaction)
    return transactions_to_send, problems, early_dates_by_id


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
        f"{format_amount(abs(amount))} from {source_name} "
        f"to {destination_name}"
    )


def find_payee_problem(payees, payee):
    # Returns why a transaction with `payee` cannot go to YNAB, or `None` when
    # it can.
    if len(payee) > YNAB_PAYEE_NAME_LIMIT:
        return f"{payee!r} is over the YNAB payee limit"
    if payee in payees.ids_by_name:
        return None
    other_names = payees.names_by_folded_name.get(payee.casefold(), set()) - {
        payee
    }
    if other_names:
        quoted_names = ", ".join(f"'{name}'" for name in sorted(other_names))
        return f"{payee!r} differs only in case from {quoted_names}"
    return None


def ask_memo(transaction):
    # Asks for the memo of `transaction`, and returns it. Returns None when
    # the reply is a dash, which means no memo.
    reply = _CTX.ask(
        f"Memo:\n{compact_line(transaction)}\n"
        f"Reply with the memo, or - for none.",
        pattern=r"[\s\S]+",
        timeout=300,
    )
    memo = reply.strip()
    return None if memo == "-" or not memo else memo


def send_transactions(
    ctx, plan, transactions, decisions, transfer_early_dates=None
):
    # Asks for a memo for each of `transactions` without a stored memo, then
    # adds them to YNAB. Only singles from before the memo question lack a
    # stored memo. Stores those memos in `decisions`. The Questrade
    # reconciliation keeps its own memo, so it does not come through here.
    # See `send_reconciliation`. Paired managed transfers go on the earliest
    # bank date of the pair, single-sided ones go on their bank date, since
    # YNAB keeps both legs on one date.
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
        if transfer_early_dates is None:
            ynab_date = transaction.date
        else:
            ynab_date = transfer_early_dates.get(
                id(transaction), transaction.date
            )
        new_transactions.append(
            ynab.NewTransaction(
                account_id=plan.account_ids[transaction.account],
                var_date=ynab_date,
                amount=to_milliunits(transaction.amount),
                payee_id=payee_id,
                payee_name=payee_name,
                # An explicit null keeps YNAB from guessing a category.
                category_id=None,
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
        # An explicit null keeps YNAB from guessing a category.
        category_id=None,
        memo=RECONCILIATION_MEMO,
        cleared=ynab.TransactionClearedStatus.CLEARED,
        approved=False,
    )
    create_ynab_transactions(plan, [transaction])


def create_ynab_transactions(plan, new_transactions):
    # Adds `new_transactions` to YNAB. Each one is a statement leg, so it
    # must be cleared and not approved. YNAB adds the other side of each
    # transfer by itself on the same date. Each other side stays uncleared
    # and not approved, unless its statement already exists, in which case
    # the later uncleared flow clears it. YNAB keeps both legs of a transfer
    # on one date, so cross-day bank pairs go on the earliest bank date and
    # no leg moves afterwards. Last, raises when YNAB holds any sent leg as
    # approved or not cleared, or any other side as approved or cleared.
    transactions_api = ynab.TransactionsApi(plan.api_client)
    try:
        response = transactions_api.create_transaction(
            plan.plan_id,
            ynab.PostTransactionsWrapper(transactions=new_transactions),
        )
    except YNAB_ERRORS as error:
        raise TaskError(
            f"cannot add the transactions to YNAB: {error}"
        ) from error
    # The last state of each transaction, by its ID.
    saved_list = saved_transactions_of(response)
    saved_transactions = {
        transaction.id: transaction for transaction in saved_list
    }
    sent_ids = set(saved_transactions)

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
                cleared=ynab.TransactionClearedStatus.UNCLEARED,
                approved=False,
            )
            for transaction_id in other_side_ids
        ]
        try:
            response = transactions_api.update_transactions(
                plan.plan_id,
                ynab.PatchTransactionsWrapper(transactions=updates),
            )
        except YNAB_ERRORS as error:
            raise TaskError(
                f"cannot update the other sides in YNAB: {error}"
            ) from error
        for transaction in saved_transactions_of(response):
            saved_transactions[transaction.id] = transaction

    wrong_sent = [
        transaction
        for transaction_id, transaction in saved_transactions.items()
        if transaction_id in sent_ids
        and (
            transaction.approved
            or transaction.cleared != ynab.TransactionClearedStatus.CLEARED
        )
    ]
    wrong_others = [
        transaction
        for transaction_id, transaction in saved_transactions.items()
        if transaction_id not in sent_ids
        and (
            transaction.approved
            or transaction.cleared != ynab.TransactionClearedStatus.UNCLEARED
        )
    ]
    if wrong_sent:
        for transaction in wrong_sent:
            _log(f"  {describe_ynab_transaction(transaction)}")
        raise TaskError("YNAB holds new transactions as approved or uncleared")
    if wrong_others:
        for transaction in wrong_others:
            _log(f"  {describe_ynab_transaction(transaction)}")
        raise TaskError("YNAB holds other sides as approved or cleared")


def clear_ynab_transactions(plan, ynab_transactions):
    # Makes each of `ynab_transactions` cleared, and leaves the rest of it as
    # it is, such as its approval.
    updates = [
        ynab.SaveTransactionWithIdOrImportId(
            id=ynab_transaction.id,
            cleared=ynab.TransactionClearedStatus.CLEARED,
        )
        for ynab_transaction in ynab_transactions
    ]
    try:
        ynab.TransactionsApi(plan.api_client).update_transactions(
            plan.plan_id, ynab.PatchTransactionsWrapper(transactions=updates)
        )
    except YNAB_ERRORS as error:
        raise TaskError(
            f"cannot clear the transactions in YNAB: {error}"
        ) from error


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
    # Returns the expected YNAB memo by statement key, with the decision row,
    # part index, and account behind each one. Skips rows without a stored
    # memo and keys with more than one memo, which need no check. Paired
    # managed transfers use the earliest bank date of the pair, which is the
    # single date that YNAB holds.
    memo_map = {}
    ambiguous_keys = set()
    early_by_ref = decision_transfer_early_dates(decisions)
    for decision in decisions:
        source, date_iso, _bank_payee, bank_amount = decision["key"]
        account = ACCOUNTS_BY_SOURCE[source]
        bank_date = datetime.date.fromisoformat(date_iso)
        if decision["kind"] == "single":
            if not decision["memo_ready"]:
                continue
            candidates = [
                (decision["payee"], bank_amount, decision["memo"], None)
            ]
        else:
            candidates = [
                (part["payee"], part["amount"], part["memo"], part_index)
                for part_index, part in enumerate(decision["parts"])
            ]
        for payee, amount, memo, part_index in candidates:
            effective_date = early_by_ref.get(
                (decision["key"], part_index), bank_date
            )
            key = statement_key(
                Transaction(
                    date=effective_date,
                    amount=amount,
                    payee=payee,
                    account=account,
                )
            )
            if key in memo_map:
                ambiguous_keys.add(key)
            else:
                memo_map[key] = {
                    "memo": memo,
                    "row": decision,
                    "part": part_index,
                    "account": account,
                }
    for key in ambiguous_keys:
        del memo_map[key]
    return memo_map


def normalize_memo(memo):
    # Returns the memo for comparison: stripped text, or "" for none.
    return (memo or "").strip()


def find_memo_mismatches(comparison, memo_map, doomed_ids):
    # Returns one item per statement key whose YNAB copies hold a different
    # memo than the decision stores. Skips doomed copies, which leave YNAB,
    # and entries of other accounts, which never match here.
    mismatches = []
    for account in YNAB_ACCOUNT_NAMES:
        ynab_by_key = comparison.ynab_by_key_by_account.get(account, {})
        for key, entry in memo_map.items():
            if entry["account"] != account:
                continue
            copies = [
                candidate
                for candidate in ynab_by_key.get(key, [])
                if candidate.id not in doomed_ids
                and normalize_memo(candidate.memo)
                != normalize_memo(entry["memo"])
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
                {
                    "account": item["account"],
                    "key": item["key"],
                    "txn": copy,
                    "memo": stored,
                }
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
    ynab_options = sorted({normalize_memo(copy.memo) for copy in copies})
    lines = [
        (
            f"{date.strftime('%m-%d')} {ACCOUNT_TAGS[account]} "
            f"{format_amount(from_milliunits(milliunits))} {payee}"
        ),
        f"Database: {display_memo(stored)}",
        "YNAB: " + ", ".join(display_memo(option) for option in ynab_options),
        "Update YNAB or the database? Reply `ynab` or `db`.",
    ]
    return (
        ctx.ask(
            "\n".join(lines), pattern=r"(?i:ynab|db)", timeout=300
        ).casefold()
        == "ynab"
    )


def display_memo(memo):
    # Returns the full memo for the chat: quoted text, or `(none)` for none.
    text = normalize_memo(memo)
    if not text:
        return "(none)"
    return f'"{text}"'


def update_ynab_memos(plan, push_items):
    # Sets the stored memo on the given YNAB transactions in one call.
    updates = [
        ynab.SaveTransactionWithIdOrImportId(
            id=item["txn"].id, memo=item["memo"]
        )
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
        lines.append(
            f"{date.strftime('%m-%d')} {ACCOUNT_TAGS[account]} "
            f"{format_amount(from_milliunits(milliunits))} {payee} "
            f"-> {display_memo(items[0]['memo'])}"
        )
    if len(groups) > REPORT_LINE_LIMIT:
        lines.append(f"+{len(groups) - REPORT_LINE_LIMIT} more")
    _say("\n".join(lines))


def canonical_expected_payee(payee):
    # Returns the payee for comparison: a transfer in canonical
    # `Transfer: <account name>` form, anything else as stored.
    target_name = transfer_target(payee)
    if target_name is None:
        return payee
    return transfer_payee(target_name)


def expected_sync_groups(decisions, start_date):
    # Returns the expected (payee, memo) items by (account, date, milliunits)
    # for every decision row dated on or after `start_date`. A single counts
    # `count` times; each split part counts `count` times. Singles without a
    # stored memo keep their payee with the memo marked unknown. Paired
    # managed transfers group on the earliest bank date of the pair, which
    # is the single date that YNAB holds. The start filter uses the bank
    # date, so a later leg still counts while its bank date is in scope.
    groups = collections.defaultdict(list)
    early_by_ref = decision_transfer_early_dates(decisions)
    for decision in decisions:
        source, date_iso, bank_payee, bank_amount = decision["key"]
        account = ACCOUNTS_BY_SOURCE[source]
        bank_date = datetime.date.fromisoformat(date_iso)
        if bank_date < start_date:
            continue
        if decision["kind"] == "single":
            candidates = [
                (
                    decision["payee"],
                    bank_amount,
                    decision.get("memo"),
                    decision["memo_ready"],
                    None,
                )
            ]
        else:
            candidates = [
                (part["payee"], part["amount"], part["memo"], True, part_index)
                for part_index, part in enumerate(decision["parts"])
            ]
        for payee, amount, memo, memo_known, part_index in candidates:
            milliunits = to_milliunits(amount)
            effective_date = early_by_ref.get(
                (decision["key"], part_index), bank_date
            )
            item = {
                "payee": payee,
                "payee_c": canonical_expected_payee(payee),
                "memo": memo,
                "memo_known": memo_known,
                "row": decision,
                "part": part_index,
                "bank_payee": bank_payee,
            }
            for _ in range(decision["count"]):
                groups[(account, effective_date, milliunits)].append(item)
    return groups


def actual_sync_groups(comparison, start_date, doomed_ids):
    # Returns the YNAB (payee, memo) items by (account, date, milliunits),
    # leaving out doomed copies, which leave YNAB through deletion, and
    # anything before `start_date`.
    groups = collections.defaultdict(list)
    for account in YNAB_ACCOUNT_NAMES:
        entries = comparison.ynab_by_key_by_account.get(account, {})
        for (date, payee_c, milliunits), txns in entries.items():
            if date < start_date:
                continue
            for txn in txns:
                if txn.id in doomed_ids:
                    continue
                groups[(account, date, milliunits)].append(
                    {
                        "payee_c": payee_c,
                        "memo_n": normalize_memo(txn.memo),
                        "txn": txn,
                    }
                )
    return groups


def find_sync_mismatches(expected_groups, actual_groups):
    # Returns one item per recognized YNAB transaction whose (payee, memo)
    # has no match in the database, with the transfer pairs in scope. Only
    # groups with equal counts on both sides pair up; groups with missing or
    # surplus copies stay with the add/delete flow. Identical pairs match
    # first, so several transactions of one amount with different memos each
    # find their own match, and singles without a stored memo match any memo
    # on their payee. Each mismatch carries its transfer link, when the other
    # leg is also here: its transaction, account, pairing-time payee, and
    # paired database item, if that leg paired. Each pair lists both legs the
    # same way, so a later pass can still sync pairs whose sides each match
    # locally but disagree with each other.
    mismatches = []
    paired_expected = {}
    by_txn_id = {}
    for group_key, actual in actual_groups.items():
        for item in actual:
            by_txn_id[item["txn"].id] = (group_key, item)
    for group_key in sorted(expected_groups):
        account, date, milliunits = group_key
        expected = expected_groups[group_key]
        actual = actual_groups.get(group_key, [])
        if not expected or len(expected) != len(actual):
            continue
        by_tuple = collections.defaultdict(collections.deque)
        unknown_by_payee = collections.defaultdict(collections.deque)
        for index, item in enumerate(expected):
            if item["memo_known"]:
                by_tuple[
                    (item["payee_c"], normalize_memo(item["memo"]))
                ].append(index)
            else:
                unknown_by_payee[item["payee_c"]].append(index)
        matched_exp = set()
        matched_act = set()
        for other, item in enumerate(actual):
            pair_key = (item["payee_c"], item["memo_n"])
            if by_tuple.get(pair_key):
                index = by_tuple[pair_key].popleft()
                matched_exp.add(index)
                matched_act.add(other)
                paired_expected[item["txn"].id] = expected[index]
        for other, item in enumerate(actual):
            if other in matched_act:
                continue
            if unknown_by_payee.get(item["payee_c"]):
                index = unknown_by_payee[item["payee_c"]].popleft()
                matched_exp.add(index)
                matched_act.add(other)
                paired_expected[item["txn"].id] = expected[index]
        remaining_exp = [
            index for index in range(len(expected)) if index not in matched_exp
        ]
        remaining_act = [
            other for other in range(len(actual)) if other not in matched_act
        ]
        if not remaining_exp:
            continue
        remaining_exp.sort(
            key=lambda index: (
                expected[index]["payee_c"],
                normalize_memo(expected[index]["memo"])
                if expected[index]["memo_known"]
                else "",
            )
        )
        remaining_act.sort(
            key=lambda other: (
                actual[other]["payee_c"],
                actual[other]["memo_n"],
            )
        )
        for index, other in zip(remaining_exp, remaining_act):
            paired_expected[actual[other]["txn"].id] = expected[index]
            mismatches.append(
                {
                    "account": account,
                    "date": date,
                    "milliunits": milliunits,
                    "expected": expected[index],
                    "actual": actual[other],
                    "transfer": None,
                }
            )
    transfer_pairs = {}
    for txn_id, (group_key, item) in by_txn_id.items():
        account, date, milliunits = group_key
        txn = item["txn"]
        other_id = txn.transfer_transaction_id
        if other_id is None or other_id == txn_id:
            continue
        found = by_txn_id.get(other_id)
        if found is None:
            continue
        pair_id = tuple(sorted([txn_id, other_id]))
        if pair_id in transfer_pairs:
            continue
        other_group_key, other_item = found
        other_account, other_date, other_milliunits = other_group_key
        transfer_pairs[pair_id] = {
            "id": pair_id,
            "sides": [
                {
                    "account": account,
                    "date": date,
                    "milliunits": milliunits,
                    "txn": txn,
                    "payee_c": item["payee_c"],
                    "expected": paired_expected.get(txn_id),
                },
                {
                    "account": other_account,
                    "date": other_date,
                    "milliunits": other_milliunits,
                    "txn": other_item["txn"],
                    "payee_c": other_item["payee_c"],
                    "expected": paired_expected.get(other_id),
                },
            ],
        }
    for item in mismatches:
        txn = item["actual"]["txn"]
        other_id = txn.transfer_transaction_id
        if other_id is None or other_id == txn.id:
            continue
        pair = transfer_pairs.get(tuple(sorted([txn.id, other_id])))
        if pair is None:
            continue
        if pair["sides"][0]["txn"].id == txn.id:
            other_side = pair["sides"][1]
        else:
            other_side = pair["sides"][0]
        item["transfer"] = {
            "pair_id": pair["id"],
            "txn": other_side["txn"],
            "account": other_side["account"],
            "date": other_side["date"],
            "milliunits": other_side["milliunits"],
            "payee_c": other_side["payee_c"],
            "expected": other_side["expected"],
        }
    return mismatches, list(transfer_pairs.values())


def ask_sync_direction(
    ctx,
    account,
    date,
    milliunits,
    bank_payee,
    stored_payee,
    stored_memo,
    stored_known,
    actual_payee_c,
    actual_memo_n,
):
    # Asks whether one recognized pair takes the payee and memo of the
    # database or of YNAB. Returns True for YNAB.
    if stored_known:
        database_memo = display_memo(stored_memo)
    else:
        database_memo = "(not set)"
    lines = [
        (
            f"{date.strftime('%m-%d')} {ACCOUNT_TAGS[account]} "
            f"{format_amount(from_milliunits(milliunits))} {stored_payee}"
        ),
        f"Bank: {bank_payee}",
        (
            f'Database: payee "{canonical_expected_payee(stored_payee)}" '
            f"memo {database_memo}"
        ),
        f'YNAB: payee "{actual_payee_c}" memo {display_memo(actual_memo_n)}',
        "Update YNAB or the database? Reply `ynab` or `db`.",
    ]
    return (
        ctx.ask(
            "\n".join(lines), pattern=r"(?i:ynab|db)", timeout=300
        ).casefold()
        == "ynab"
    )


def plan_payee_update(plan, account, payee):
    # Returns the (payee_id, payee_name, problem) for writing `payee` to a
    # YNAB transaction in `account`. A problem explains why the payee cannot
    # go to YNAB; None means it can.
    target_name = transfer_target(payee)
    if target_name is None:
        return (
            plan.payees.ids_by_name.get(payee),
            payee,
            find_payee_problem(plan.payees, payee),
        )
    if target_name == YNAB_ACCOUNT_NAMES[account]:
        return None, None, "transfer to its own account"
    if target_name not in plan.transfer_payee_ids:
        return None, None, f"no open YNAB account {target_name!r}"
    return plan.transfer_payee_ids[target_name], None, None


def ynab_payee_for_database(plan, txn):
    # Returns the database form of the payee of a YNAB transaction:
    # transfers in canonical form, anything else stripped as stored.
    if txn.transfer_account_id is None:
        return (txn.payee_name or "").strip()
    return transfer_payee(
        plan.account_names.get(
            txn.transfer_account_id, str(txn.transfer_account_id)
        )
    )


def database_payee_problem(payee):
    # Returns why the YNAB payee `payee` cannot go to the database, or None
    # when it can.
    clean = payee.strip() if isinstance(payee, str) else ""
    if not clean:
        return "has no payee"
    if len(clean) > YNAB_PAYEE_NAME_LIMIT:
        return "is over the YNAB payee limit"
    return None


def apply_adopt_to_transactions(
    transactions,
    account,
    date,
    milliunits,
    old_payee_c,
    old_memo_n,
    memo_known,
    new_payee,
    new_memo,
    cap,
    update_memo=True,
):
    # Writes an adopted payee and memo into the statement transactions that
    # produced the old pair, up to `cap` copies, so the add/delete flow below
    # plans on the new values. Twins from distinct rows share one pair form,
    # so the cap keeps each adoption to its own row. Without `update_memo`
    # only the payee changes, for transfer sides whose memo settled apart.
    updated = 0
    for transaction in transactions:
        if updated >= cap:
            break
        if transaction.account != account or transaction.date != date:
            continue
        if to_milliunits(transaction.amount) != milliunits:
            continue
        if canonical_expected_payee(transaction.payee) != old_payee_c:
            continue
        if memo_known and normalize_memo(transaction.memo) != old_memo_n:
            continue
        transaction.payee = new_payee
        if update_memo:
            transaction.memo = new_memo
            transaction.memo_ready = True
        updated += 1


def current_expected_values(row, part_index):
    # Returns the (payee, memo, memo_known) that the decision row or split
    # part stores now. Reads live, so earlier answers in the same run show.
    if part_index is None:
        return row.get("payee"), row.get("memo"), bool(row.get("memo_ready"))
    part = row["parts"][part_index]
    return part["payee"], part["memo"], True


def decision_part_milliunits(row, part_index):
    # Returns the milliunits of one database side: the bank amount for a
    # whole, the part amount for a split.
    if part_index is None:
        return to_milliunits(row["key"][3])
    return to_milliunits(row["parts"][part_index]["amount"])


def append_sync_push(
    push_items,
    account,
    txn,
    old_payee_c,
    old_memo_n,
    memo,
    new_payee=None,
    payee_id=None,
    payee_name=None,
    transfer_change=False,
):
    # Stages a YNAB update and mirrors the memo in memory, so later questions
    # read decided values. Old values stay on the item for the chat. Without
    # a new payee the item updates the memo only, leaving the payee alone.
    item = {
        "account": account,
        "txn": txn,
        "memo": memo,
        "new_payee": new_payee,
        "old_payee_c": old_payee_c,
        "old_memo_n": old_memo_n,
        "transfer_change": transfer_change,
    }
    if new_payee is not None:
        item["payee_id"] = payee_id
        item["payee_name"] = payee_name
    push_items.append(item)
    txn.memo = memo


def ask_sync_payee_direction(
    ctx, account, date, milliunits, bank_payee, stored_payee, actual_payee_c
):
    # Asks whether one transfer side takes the payee of the database or of
    # YNAB. Memos go through the pair question. Returns True for YNAB.
    lines = [
        (
            f"{date.strftime('%m-%d')} {ACCOUNT_TAGS[account]} "
            f"{format_amount(from_milliunits(milliunits))} {stored_payee}"
        ),
        f"Bank: {bank_payee}",
        f'Database payee: "{canonical_expected_payee(stored_payee)}"',
        f'YNAB payee: "{actual_payee_c}"',
        "Update YNAB or the database? Reply `ynab` or `db`.",
    ]
    return (
        ctx.ask(
            "\n".join(lines), pattern=r"(?i:ynab|db)", timeout=300
        ).casefold()
        == "ynab"
    )


def transfer_memo_lines(date, milliunits, sides):
    # Returns the chat lines for one transfer pair memo question. Each side
    # holds its account with its database and YNAB memo display strings.
    # Sorts by account, so every question about the pair matches.
    ordered = sorted(sides, key=lambda side: side[0].value)
    accounts = " <-> ".join(ACCOUNT_TAGS[account] for account, _, _ in ordered)
    lines = [
        (
            f"{date.strftime('%m-%d')} Transfer "
            f"{accounts} "
            f"{format_amount(from_milliunits(milliunits))}"
        )
    ]
    for account, db_disp, _ in ordered:
        lines.append(f"Database {ACCOUNT_TAGS[account]}: {db_disp}")
    for account, _, ynab_disp in ordered:
        lines.append(f"YNAB {ACCOUNT_TAGS[account]}: {ynab_disp}")
    return lines


def ask_pair_memo_value(ctx, lines):
    # Asks for one typed memo for a transfer pair, so both sides converge
    # without retyping anything from memory. Returns it normalized, or None.
    reply = ctx.ask(
        "\n".join(
            lines + ["Reply with the memo for both sides, or - for none."]
        ),
        pattern=r"[\s\S]+",
        timeout=300,
    ).strip()
    return normalize_memo(reply) or None


def apply_pair_memo(transactions, push_items, legs, db_refs, value):
    # Writes one memo across a transfer pair: both YNAB legs, skipping legs
    # already there, and every given database side with its statement
    # transactions. `value` is normalized, or None for none. Returns whether
    # the database changed.
    stored = value or None
    for account, txn, old_payee_c in legs:
        if normalize_memo(txn.memo) == normalize_memo(value):
            continue
        append_sync_push(
            push_items,
            account,
            txn,
            old_payee_c,
            normalize_memo(txn.memo),
            stored,
        )
    changed = False
    for row, part, account in db_refs:
        payee, memo, known = current_expected_values(row, part)
        if known and normalize_memo(memo) == normalize_memo(value):
            continue
        if part is None:
            row["memo"] = stored
            row["memo_ready"] = True
        else:
            row["parts"][part]["memo"] = stored
        apply_adopt_to_transactions(
            transactions,
            account,
            datetime.date.fromisoformat(row["key"][1]),
            decision_part_milliunits(row, part),
            canonical_expected_payee(payee),
            normalize_memo(memo) if known else None,
            known,
            payee,
            stored,
            row["count"],
        )
        changed = True
    return changed


def ask_transfer_reuse(ctx, item, recorded):
    # Asks whether one transfer side takes the memo the other side already
    # set, instead of retyping it. Returns True for yes.
    account = item["account"]
    expected = item["expected"]
    stored_payee, _, _ = current_expected_values(
        expected["row"], expected["part"]
    )
    amount = format_amount(from_milliunits(item["milliunits"]))
    lines = [
        (
            f"{item['date'].strftime('%m-%d')} {ACCOUNT_TAGS[account]} "
            f"{amount} {stored_payee}"
        ),
        f"Bank: {expected['bank_payee']}",
        f"The other side uses memo {display_memo(recorded)}. Use it here too?",
    ]
    return ask_yes("\n".join(lines))


def pair_memo_parts(sides):
    # Splits transfer pair `sides` into legs for staging, database refs for
    # adopting, display tuples, and the distinct memo set, all read live.
    # Each side holds its account, transaction, pairing-time payee, and paired
    # database item, if that leg paired.
    legs = []
    db_refs = []
    displays = []
    values = set()
    for side in sides:
        account = side["account"]
        txn = side["txn"]
        live = normalize_memo(txn.memo)
        values.add(live)
        legs.append((account, txn, side["payee_c"]))
        if side["expected"] is None:
            db_disp = "(no decision)"
        else:
            row = side["expected"]["row"]
            _, memo, known = current_expected_values(
                row, side["expected"]["part"]
            )
            if known:
                values.add(normalize_memo(memo))
                db_disp = display_memo(memo)
            else:
                db_disp = "(not set)"
            db_refs.append((row, side["expected"]["part"], account))
        displays.append((account, db_disp, display_memo(live)))
    return legs, db_refs, displays, values


def resolve_joint_mismatch(ctx, plan, transactions, push_items, item):
    # Asks one ynab/db question covering the payee and memo of a pair, stages
    # a YNAB push or adopts into the decision row and its statement
    # transactions at once. Reads every value fresh. Returns (adopted,
    # decided memo for the pair, normalized).
    account = item["account"]
    expected = item["expected"]
    txn = item["actual"]["txn"]
    row = expected["row"]
    stored_payee, stored_memo, stored_known = current_expected_values(
        row, expected["part"]
    )
    stored_c = canonical_expected_payee(stored_payee)
    actual_payee_c = item["actual"]["payee_c"]
    actual_memo_n = normalize_memo(txn.memo)
    if stored_c == actual_payee_c and (
        not stored_known or normalize_memo(stored_memo) == actual_memo_n
    ):
        return False, None
    if ask_sync_direction(
        ctx,
        account,
        item["date"],
        item["milliunits"],
        expected["bank_payee"],
        stored_payee,
        stored_memo,
        stored_known,
        actual_payee_c,
        actual_memo_n,
    ):
        payee_id, payee_name, problem = plan_payee_update(
            plan, account, stored_payee
        )
        if problem is not None:
            raise TaskError(
                f"Cannot write payee {stored_payee!r} to YNAB: {problem}. "
                "Fix the names in YNAB or in `transactions.json` and rerun."
            )
        if stored_known:
            new_memo = stored_memo
            decided = normalize_memo(stored_memo)
        else:
            # No stored memo exists, so only the payee changes.
            new_memo = txn.memo
            decided = actual_memo_n
        append_sync_push(
            push_items,
            account,
            txn,
            actual_payee_c,
            actual_memo_n,
            new_memo,
            new_payee=stored_payee,
            payee_id=payee_id,
            payee_name=payee_name,
            transfer_change=transfer_target(actual_payee_c)
            != transfer_target(stored_payee),
        )
        return False, decided
    new_payee = ynab_payee_for_database(plan, txn)
    problem = database_payee_problem(new_payee)
    if problem is not None:
        raise TaskError(
            f"YNAB payee {actual_payee_c!r} {problem}, so the database "
            "cannot adopt it. Fix it in YNAB and rerun."
        )
    new_memo = actual_memo_n or None
    if expected["part"] is None:
        row["payee"] = new_payee
        row["memo"] = new_memo
        row["memo_ready"] = True
    else:
        row["parts"][expected["part"]]["payee"] = new_payee
        row["parts"][expected["part"]]["memo"] = new_memo
    apply_adopt_to_transactions(
        transactions,
        account,
        item["date"],
        item["milliunits"],
        stored_c,
        normalize_memo(stored_memo) if stored_known else None,
        stored_known,
        new_payee,
        new_memo,
        row["count"],
    )
    return True, actual_memo_n


def handle_transfer_memo(ctx, transactions, push_items, pair_memos, item):
    # Syncs the memo of one transfer side with its pair. Offers the memo the
    # other side already set instead of retyping it; asks the pair for one
    # typed value when nothing decided fits; flags a joint payee-and-memo
    # question when this side carries a known differing memo. Reads every
    # value fresh. Returns (adopted, recorded memo or None, joint needed).
    link = item["transfer"]
    pair_id = link["pair_id"]
    account = item["account"]
    expected = item["expected"]
    txn = item["actual"]["txn"]
    row = expected["row"]
    _stored_payee, stored_memo, stored_known = current_expected_values(
        row, expected["part"]
    )
    actual_memo_n = normalize_memo(txn.memo)
    recorded = pair_memos.get(pair_id)
    if recorded is not None:
        if actual_memo_n == recorded and (
            not stored_known or normalize_memo(stored_memo) == recorded
        ):
            return False, None, False
        if ask_transfer_reuse(ctx, item, recorded):
            changed = apply_pair_memo(
                transactions,
                push_items,
                [(account, txn, item["actual"]["payee_c"])],
                [(row, expected["part"], account)],
                recorded,
            )
            return changed, None, False
        sides = [
            {
                "account": account,
                "txn": txn,
                "payee_c": item["actual"]["payee_c"],
                "expected": expected,
            },
            {
                "account": link["account"],
                "txn": link["txn"],
                "payee_c": link["payee_c"],
                "expected": link["expected"],
            },
        ]
        legs, db_refs, displays, _values = pair_memo_parts(sides)
        value = ask_pair_memo_value(
            ctx,
            transfer_memo_lines(item["date"], item["milliunits"], displays),
        )
        return (
            apply_pair_memo(transactions, push_items, legs, db_refs, value),
            value,
            False,
        )
    if stored_known and actual_memo_n != normalize_memo(stored_memo):
        return False, None, True
    sides = [
        {
            "account": account,
            "txn": txn,
            "payee_c": item["actual"]["payee_c"],
            "expected": expected,
        },
        {
            "account": link["account"],
            "txn": link["txn"],
            "payee_c": link["payee_c"],
            "expected": link["expected"],
        },
    ]
    legs, db_refs, displays, values = pair_memo_parts(sides)
    if len(values) <= 1:
        return False, None, False
    value = ask_pair_memo_value(
        ctx, transfer_memo_lines(item["date"], item["milliunits"], displays)
    )
    return (
        apply_pair_memo(transactions, push_items, legs, db_refs, value),
        value,
        False,
    )


def handle_transfer_payee(ctx, plan, transactions, push_items, item):
    # Asks for one transfer side's payee after its memo settled. Stages a
    # YNAB push with the live memo, or adopts only the payee into the row.
    # Reads every value fresh. Returns whether the database changed.
    account = item["account"]
    expected = item["expected"]
    txn = item["actual"]["txn"]
    row = expected["row"]
    stored_payee, _, _ = current_expected_values(row, expected["part"])
    stored_c = canonical_expected_payee(stored_payee)
    actual_payee_c = item["actual"]["payee_c"]
    if stored_c == actual_payee_c:
        return False
    if ask_sync_payee_direction(
        ctx,
        account,
        item["date"],
        item["milliunits"],
        expected["bank_payee"],
        stored_payee,
        actual_payee_c,
    ):
        payee_id, payee_name, problem = plan_payee_update(
            plan, account, stored_payee
        )
        if problem is not None:
            raise TaskError(
                f"Cannot write payee {stored_payee!r} to YNAB: {problem}. "
                "Fix the names in YNAB or in `transactions.json` and rerun."
            )
        append_sync_push(
            push_items,
            account,
            txn,
            actual_payee_c,
            normalize_memo(txn.memo),
            txn.memo,
            new_payee=stored_payee,
            payee_id=payee_id,
            payee_name=payee_name,
            transfer_change=transfer_target(actual_payee_c)
            != transfer_target(stored_payee),
        )
        return False
    new_payee = ynab_payee_for_database(plan, txn)
    problem = database_payee_problem(new_payee)
    if problem is not None:
        raise TaskError(
            f"YNAB payee {actual_payee_c!r} {problem}, so the database "
            "cannot adopt it. Fix it in YNAB and rerun."
        )
    if expected["part"] is None:
        row["payee"] = new_payee
    else:
        row["parts"][expected["part"]]["payee"] = new_payee
    _, fresh_memo, fresh_known = current_expected_values(row, expected["part"])
    apply_adopt_to_transactions(
        transactions,
        account,
        item["date"],
        item["milliunits"],
        stored_c,
        normalize_memo(fresh_memo) if fresh_known else None,
        fresh_known,
        new_payee,
        None,
        row["count"],
        update_memo=False,
    )
    return True


def reconcile_transfer_pairs(ctx, transactions, push_items, transfer_pairs):
    # Asks once per still-diverged transfer pair for one memo for both sides,
    # covering pairs no side question settled. Reads every value fresh.
    # Returns whether the database changed.
    adopted = False
    ordered = sorted(
        transfer_pairs,
        key=lambda pair: (
            min(side["account"].value for side in pair["sides"]),
            max(side["account"].value for side in pair["sides"]),
            pair["id"],
        ),
    )
    for pair in ordered:
        legs, db_refs, displays, values = pair_memo_parts(pair["sides"])
        if len(values) <= 1:
            continue
        first = min(pair["sides"], key=lambda side: side["account"].value)
        value = ask_pair_memo_value(
            ctx,
            transfer_memo_lines(first["date"], first["milliunits"], displays),
        )
        if apply_pair_memo(transactions, push_items, legs, db_refs, value):
            adopted = True
    return adopted


def resolve_sync_mismatches(
    ctx, plan, decisions, transactions, mismatches, transfer_pairs
):
    # Asks about each recognized pair and returns the YNAB transactions to
    # update with their new payee and memo, with whether the database took
    # any YNAB values. Each transfer side checks its payee on its own, while
    # the pair shares its memo: the second side is offered the first side's
    # memo instead of retyping it, and any leftover mismatch asks once for
    # the pair. A database answer adopts into the decision row at once, and
    # into the matching statement transactions. Raises before any change when
    # the chosen side cannot win.
    push_items = []
    adopted = False
    pair_memos = {}
    for item in mismatches:
        transfer = item.get("transfer")
        if transfer is None:
            adopted_now, _ = resolve_joint_mismatch(
                ctx, plan, transactions, push_items, item
            )
            adopted = adopted_now or adopted
            continue
        pair_id = transfer["pair_id"]
        adopted_now, recorded_now, joint_needed = handle_transfer_memo(
            ctx, transactions, push_items, pair_memos, item
        )
        if recorded_now is not None:
            pair_memos[pair_id] = recorded_now
        adopted = adopted_now or adopted
        if joint_needed:
            adopted_now, recorded_now = resolve_joint_mismatch(
                ctx, plan, transactions, push_items, item
            )
            if recorded_now is not None:
                pair_memos[pair_id] = recorded_now
            adopted = adopted_now or adopted
            continue
        adopted = (
            handle_transfer_payee(ctx, plan, transactions, push_items, item)
            or adopted
        )
    adopted = (
        reconcile_transfer_pairs(ctx, transactions, push_items, transfer_pairs)
        or adopted
    )
    if adopted:
        save_decisions(ctx, decisions)
    return push_items, adopted


def update_ynab_payees_memos(plan, push_items):
    # Sets the stored payee and memo on the given YNAB transactions in one
    # call. Items without a new payee update the memo only, leaving the payee
    # alone.
    updates = []
    for item in push_items:
        data = {"id": item["txn"].id, "memo": item["memo"]}
        if item.get("new_payee") is not None:
            data["payee_id"] = item["payee_id"]
            data["payee_name"] = item["payee_name"]
        updates.append(ynab.SaveTransactionWithIdOrImportId(**data))
    try:
        ynab.TransactionsApi(plan.api_client).update_transactions(
            plan.plan_id, ynab.PatchTransactionsWrapper(transactions=updates)
        )
    except YNAB_ERRORS as error:
        raise TaskError(
            f"cannot update the payees and memos in YNAB: {error}"
        ) from error


def say_sync_updates(push_items):
    # Reports the recognized YNAB payees and memos that the run updates, one
    # line each with the full payee.
    lines = [f"Update recognized ({len(push_items)}):"]
    for item in push_items[:REPORT_LINE_LIMIT]:
        txn = item["txn"]
        new_payee = item.get("new_payee")
        if new_payee is None:
            payee_part = f'"{item["old_payee_c"]}"'
        else:
            new_c = canonical_expected_payee(new_payee)
            if new_c == item["old_payee_c"]:
                payee_part = f'"{new_c}"'
            else:
                payee_part = f'"{item["old_payee_c"]}" -> "{new_c}"'
        memo_arrow = ""
        if item["old_memo_n"] != normalize_memo(item["memo"]):
            memo_arrow = (
                f" memo {display_memo(item['old_memo_n'])} -> "
                f"{display_memo(item['memo'])}"
            )
        lines.append(
            f"{txn.var_date.strftime('%m-%d')} "
            f"{ACCOUNT_TAGS[item['account']]} "
            f"{format_amount(from_milliunits(txn.amount))} "
            f"{payee_part}{memo_arrow}"
        )
    if len(push_items) > REPORT_LINE_LIMIT:
        lines.append(f"+{len(push_items) - REPORT_LINE_LIMIT} more")
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
            lines.append(
                f"{side.date.strftime('%m-%d')} {format_amount(side.amount)} "
                f"{side.payee}"
            )
        lines.append("Check for doubles.")
        _say("\n".join(lines))


def ynab_ignored_compact_line(account, key):
    # One compact line for a YNAB transaction that no statement holds, from
    # its comparison key. Same format as `compact_line`.
    date, payee, milliunits = key
    return (
        f"{date.strftime('%m-%d')} "
        f"{ACCOUNT_TAGS[account]} "
        f"{format_amount(from_milliunits(milliunits))} {payee}"
    )


def report_ignored_counts(comparison):
    # Sends, for each account, the YNAB transactions that no statement holds
    # and the task leaves as they are, one compact line each. Surplus copies
    # of bank entries are deletions, not ignored entries.
    for account, ynab_name in YNAB_ACCOUNT_NAMES.items():
        expected = comparison.expected_keys_by_account.get(account, set())
        ignored = [
            key
            for key in comparison.extra_keys_by_account.get(account, [])
            if key not in expected
        ]
        if not ignored:
            continue
        # By date, then by amount, then by payee, like `report_order`.
        ignored = sorted(ignored, key=lambda key: (key[0], key[2], key[1]))
        _log(f"Ignored {len(ignored)} in {ynab_name}, not in its statement")
        for key in ignored:
            _log(f"  ignored: {ynab_ignored_compact_line(account, key)}")
        lines = [
            f"Ignored in {ynab_name} ({len(ignored)}), not in its statement:"
        ]
        lines += [
            ynab_ignored_compact_line(account, key)
            for key in ignored[:REPORT_LINE_LIMIT]
        ]
        if len(ignored) > REPORT_LINE_LIMIT:
            lines.append(f"+{len(ignored) - REPORT_LINE_LIMIT} more")
        _say("\n".join(lines))


def ynab_memo_missing(ynab_transaction):
    # Returns whether the YNAB transaction has no memo. A memo with only
    # spaces counts as no memo, like a missing one.
    return not (getattr(ynab_transaction, "memo", None) or "").strip()


def report_memo_count(comparison, start_date):
    # Reports how many YNAB transactions in the period have no memo. The
    # count comes from the comparison, so after the changes it already
    # includes the transactions that the current run added.
    count = comparison.ynab_without_memo_count
    _log(
        f"transactions without a memo since {start_date.isoformat()}: {count}"
    )
    _say(
        f"{count} transactions without a memo since {start_date.isoformat()}."
    )


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
            _log(
                f"  not cleared: {describe_ynab_transaction(ynab_transaction)}"
            )


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


# -----------------------------------------------------------------------------
# Browser.
# -----------------------------------------------------------------------------


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
            command,
            stdout=stdout,
            stderr=stderr,
            encoding="utf-8",
            errors="replace",
            check=False,
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
