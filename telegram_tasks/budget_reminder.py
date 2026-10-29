# Reminder that budget_sync still needs to run today.
#
# Runs once per hour between noon and midnight. It reads the last-run state
# that budget_sync stores, and reminds the chat when budget_sync has not run
# yet today. Only a finished run without flags stores today, so a run with
# --no-download or --no-upload still counts as pending.

NAME = "budget_reminder"
DESCRIPTION = "Remind to run /budget_sync when it hasn't run today."
SHORTHAND = "br"
TIMEOUT = 120
SCHEDULE = "0 12-23 * * *"

import datetime
import json

# The task to watch, and the state identifier where it stores its last run.
BUDGET_SYNC_TASK = "budget_sync"
LAST_RUN_ID = "last_run.json"
REMINDER_MESSAGE = "Run `/budget_sync`, it's still pending today."


def run(ctx, args=None):
    """Remind when budget_sync has not run today. Stays silent otherwise."""
    raw = ctx.load_state(LAST_RUN_ID, task_name=BUDGET_SYNC_TASK)
    if raw is not None and ran_today(raw):
        ctx.log("budget_sync already ran today, staying silent.")
        return "budget_sync already ran today."
    ctx.say(REMINDER_MESSAGE)
    return "Reminded that budget_sync is pending."


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
