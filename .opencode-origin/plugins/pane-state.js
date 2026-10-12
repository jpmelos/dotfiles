// Update the tmux pane state from OpenCode lifecycle events.
//
// This mirrors the `hooks` in `.claude-origin/settings.json`. The `running`,
// `ready`, and `default` binaries are mounted at `/usr/local/bin` by `bin/oc`.
// Without `TMUX_PANE` they exit with success and do nothing. Subagent child
// sessions stay silent, so only the main session changes the pane.
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
    const subagentSessionIDs = new Set();
    const mainSessionIDs = new Set();

    async function isSubagentSession(sessionID) {
      if (subagentSessionIDs.has(sessionID)) {
        return true;
      }
      if (mainSessionIDs.has(sessionID)) {
        return false;
      }
      try {
        const info = await ctx.session.get({ sessionID });
        if (info && info.parentID) {
          subagentSessionIDs.add(sessionID);
          return true;
        }
      } catch {
        // The session is gone or unreadable. Treat it as main, so the pane still updates.
        return false;
      }
      mainSessionIDs.add(sessionID);
      return false;
    }

    function forgetSession(sessionID) {
      subagentSessionIDs.delete(sessionID);
      mainSessionIDs.delete(sessionID);
    }

    // A submitted prompt starts work, like `UserPromptSubmit`.
    await ctx.session.hook("prompt", async (event) => {
      if (await isSubagentSession(event.sessionID)) {
        return;
      }
      await pane(["running"]);
    });

    // A tool about to run means work, like `PreToolUse`.
    await ctx.tool.hook("execute.before", async (event) => {
      if (await isSubagentSession(event.sessionID)) {
        return;
      }
      await pane(["running"]);
    });

    const controller = new AbortController();
    void (async () => {
      try {
        for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
          if (event.type === "session.created") {
            // A child session names its parent, so subagents stay silent.
            if (event.data.parentID) {
              subagentSessionIDs.add(event.data.sessionID);
              continue;
            }
            mainSessionIDs.add(event.data.sessionID);
            // A new session is ready for input, like `SessionStart`.
            await pane(["ready", "--no-chime"]);
          } else if (event.type === "session.execution.started") {
            if (await isSubagentSession(event.data.sessionID)) {
              continue;
            }
            // A turn started, like `UserPromptSubmit`.
            await pane(["running"]);
          } else if (
            event.type === "session.execution.succeeded" ||
            event.type === "session.execution.failed" ||
            event.type === "session.execution.interrupted"
          ) {
            if (await isSubagentSession(event.data.sessionID)) {
              continue;
            }
            // The turn ended, like `Stop`.
            await pane(["ready"]);
          } else if (event.type === "session.deleted") {
            if (subagentSessionIDs.has(event.data.sessionID)) {
              forgetSession(event.data.sessionID);
              continue;
            }
            // The session ended, like `SessionEnd`.
            await pane(["default"]);
            forgetSession(event.data.sessionID);
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
