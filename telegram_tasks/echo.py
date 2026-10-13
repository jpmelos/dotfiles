# Example task for telegram_bot. Copy this file to start a new task.
#
# A task module may define DESCRIPTION, TIMEOUT, run, and shutdown.
# Run it with /run echo from the allowlisted chat.

DESCRIPTION = "Ask for a name and a number, then store them as state."
TIMEOUT = 600


def run(ctx, args):
    ctx.log(f"started with args {args}")
    previous = ctx.load_state("echo.json")
    if previous is not None:
        ctx.say("Previous answers: " + previous.decode("utf-8"))
    name = ctx.ask("What is your name?", pattern=r".+", timeout=120)
    ctx.say(f"Hello, {name}.")
    count = ctx.ask("Send a number.", pattern=r"\d+", timeout=120)
    ctx.save_state("echo.json", {"name": name, "count": int(count)})
    return f"Stored name {name} with count {count}."


def shutdown(ctx, reason):
    ctx.log(f"shutdown with reason {reason}")
