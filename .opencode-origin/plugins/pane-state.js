// Update the tmux pane state from OpenCode lifecycle events.
//
// This mirrors the `hooks` in `.claude-origin/settings.json`. The `running`,
// `ready`, and `default` binaries are mounted at `/usr/local/bin` by `bin/oc`.
// Without `TMUX_PANE` they exit with success and do nothing.
import { execFile } from "node:child_process"

function run(command, args) {
  return new Promise((resolve) => {
    execFile(command, args, { stdio: "ignore" }, () => resolve());
  });
}

function pane(args) {
  return run(args[0], args.slice(1));
}

export default {
  id: "pane-state",
  setup: async (ctx) => {
    // A submitted prompt starts work, like `UserPromptSubmit`.
    await ctx.session.hook("prompt", async () => {
      await pane(["running"]);
    });

    // A tool about to run means work, like `PreToolUse`.
    await ctx.tool.hook("execute.before", async () => {
      await pane(["running"]);
    });

    const controller = new AbortController();
    void (async () => {
      try {
        for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
          if (event.type === "session.created") {
            // A new session is ready for input, like `SessionStart`.
            await pane(["ready", "--no-chime"]);
          } else if (event.type === "session.execution.started") {
            // A turn started, like `UserPromptSubmit`.
            await pane(["running"]);
          } else if (
            event.type === "session.execution.succeeded" ||
            event.type === "session.execution.failed" ||
            event.type === "session.execution.interrupted"
          ) {
            // The turn ended, like `Stop`.
            await pane(["ready"]);
          } else if (event.type === "session.deleted") {
            // The session ended, like `SessionEnd`.
            await pane(["default"]);
          }
        }
      } catch {
        // The subscription ends on unload. Nothing to report.
      }
    })();

    return async () => {
      controller.abort();
      // The process exits, like `SessionEnd`.
      await pane(["default"]);
    };
  },
};
