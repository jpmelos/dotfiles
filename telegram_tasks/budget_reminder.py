# Reminder that budget_sync still needs to run today.
#
# Runs once per hour between noon and midnight. It reads the last-run state
# that budget_sync stores, and reminds the chat when budget_sync has not run
# yet today. Only a finished run without flags stores today, so a run with
# --no-download or --no-upload still counts as pending.
#
# Run it with `/budget_reminder` from the allowlisted chat. Optional words
# after the name are `--skip`.
#
# With `--skip`, the task records today as skipped and stays silent. Later
# runs stay silent for the rest of the day. They skip the check of the
# last-run state.

NAME = "budget_reminder"
DESCRIPTION = "Remind to run /budget_sync when it hasn't run today."
HELP = "Flags:\n--skip: skip reminders for the rest of the day.\n"
SHORTHAND = "br"
TIMEOUT = 120
SCHEDULE = "0 12-23 * * *"

# Requirement strings that the bot installs with `uv` into the venv of the
# task on every run.
DEPENDENCIES = ("click>=8,<9",)

import datetime
import json

import click

# The task to watch, and the state identifier where it stores its last run.
BUDGET_SYNC_TASK = "budget_sync"
LAST_RUN_ID = "last_run.json"
# The state identifier where this task records a skipped day.
SKIP_ID = "skip.json"
REMINDER_MESSAGE = "Run `/budget_sync`, it's still pending today."


class TaskError(Exception):
    pass


@click.command(
    context_settings={"help_option_names": []}, no_args_is_help=False
)
@click.option("--skip", is_flag=True, default=False)
def _budget_reminder_options(skip):
    # Holds the CLI option. `parse_task_args` runs it without exit, so its
    # errors raise instead.
    return skip


def parse_task_args(args):
    # Returns skip from `args`, the words after the task name, with the same
    # rules as a regular CLI.
    # Telegram replaces `--` with an n-dash or an m-dash, so leading `-`,
    # `–` (U+2013), and `—` (U+2014) all count as `--`.
    normalized = []
    for argument in args:
        if argument.startswith(("-", "–", "—")):
            argument = "--" + argument.lstrip("-–—")
        normalized.append(argument)
    try:
        skip = _budget_reminder_options.main(normalized, standalone_mode=False)
    except click.ClickException as error:
        raise TaskError(str(error)) from error
    return skip


def run(ctx, args=None):
    """Remind when budget_sync has not run today. Stays silent otherwise."""
    skip = parse_task_args(list(args or []))
    if skip:
        record_skip(ctx)
        ctx.log("budget_sync already ran today, staying silent.")
        return "budget_sync already ran today."
    if skipped_today(ctx):
        ctx.log("budget_sync already ran today, staying silent.")
        return "budget_sync already ran today."
    raw = ctx.load_state(LAST_RUN_ID, task_name=BUDGET_SYNC_TASK)
    if raw is not None and ran_today(raw):
        ctx.log("budget_sync already ran today, staying silent.")
        return "budget_sync already ran today."
    ctx.say(REMINDER_MESSAGE)
    return "Reminded that budget_sync is pending."


def record_skip(ctx):
    # Records today as skipped, so later runs stay silent for the rest of
    # the day. A failure to store only warns, so the current run still stays
    # silent.
    today = datetime.date.today().isoformat()
    try:
        ctx.save_state(SKIP_ID, {"date": today})
    except (OSError, TaskError, ValueError, RuntimeError) as error:
        ctx.log(f"Warning: cannot save {SKIP_ID}: {error}")


def skipped_today(ctx):
    # Returns whether this task recorded a skip for today. Any missing or
    # broken state counts as not skipped, so the reminder still fires.
    raw = ctx.load_state(SKIP_ID)
    if raw is None:
        return False
    try:
        if isinstance(raw, (bytes, bytearray)):
            text = bytes(raw).decode("utf-8")
        else:
            text = str(raw)
        data = json.loads(text)
        stamp = data.get("date") if isinstance(data, dict) else None
        if not isinstance(stamp, str) or not stamp:
            return False
        skip_date = datetime.date.fromisoformat(stamp)
    except (UnicodeDecodeError, ValueError):
        return False
    return skip_date == datetime.date.today()


def ran_today(raw):
    # Returns whether `raw`, the last-run state of budget_sync, holds a
    # timestamp from today, in local time. Any missing or broken state counts
    # as not ran, so the reminder still fires.
    try:
        if isinstance(raw, (bytes, bytearray)):
            text = bytes(raw).decode("utf-8")
        else:
            text = str(raw)
        data = json.loads(text)
        stamp = data.get("last_run") if isinstance(data, dict) else None
        if not isinstance(stamp, str) or not stamp:
            return False
        run_time = datetime.datetime.fromisoformat(stamp)
    except (UnicodeDecodeError, ValueError):
        return False
    if run_time.tzinfo is None:
        run_date = run_time.date()
    else:
        run_date = run_time.astimezone().date()
    return run_date == datetime.date.today()
