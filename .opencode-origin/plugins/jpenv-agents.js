// Load files named in `jpenv-agents.json` into context.
//
// Each load prints a directive and a manifest header as a chat
// message. The model reads the message and fetches the files with
// the file tool. Root loads run with the first prompt of each
// session. Sibling loads run when a file tool runs, resolved from
// the directory of that file.

import { readFile, stat } from "node:fs/promises";
import path from "node:path";

const CONFIG_NAME = "jpenv-agents.json";
const MANIFEST_TAG = "jpenv-agents manifest";
// Tell the model to read the listed files with the file tool.
const DIRECTIVE = "Read each listed file in full with the file tool. Skip a file whose complete contents are already in context.";

// Post one file list as a chat message.
async function announce(ctx, sessionID, files) {
  const text = DIRECTIVE + "\n" + manifestBlock(files);
  try {
    await ctx.session.synthetic({ sessionID, text, description: text, resume: false });
  } catch {
    // The manifest is best-effort. A failure never stops the session.
  }
}

// Build the manifest header for one file list.
function manifestBlock(files) {
  const lines = [MANIFEST_TAG + " (" + files.length + " files):"];
  for (const file of files) {
    lines.push("- " + file);
  }
  return lines.join("\n");
}

// Read the pattern list at the project root for this run.
async function readPatterns(root) {
  let parsed;
  try {
    parsed = JSON.parse(await readFile(path.join(root, CONFIG_NAME), "utf8"));
  } catch {
    return [];
  }
  if (parsed === null || typeof parsed !== "object") {
    return [];
  }
  if (!Array.isArray(parsed.context)) {
    return [];
  }
  return parsed.context.filter((entry) => typeof entry === "string" && entry.length > 0);
}

// Expand patterns from one base directory into sorted file paths.
async function expandPatterns(patterns, base) {
  const found = new Set();
  const meta = /[*?{}[\]]/;
  const noBun = typeof Bun === "undefined" || Bun === null;
  const hasGlob = !noBun && typeof Bun.Glob === "function";
  for (const pattern of patterns) {
    const target = path.isAbsolute(pattern) ? pattern : path.join(base, pattern);
    if (!meta.test(target)) {
      try {
        if ((await stat(target)).isFile()) {
          found.add(target);
        }
      } catch {
        // Absent paths stay silent.
      }
      continue;
    }
    if (!hasGlob) {
      continue;
    }
    try {
      const glob = new Bun.Glob(target);
      for await (const match of glob.scan({ absolute: true })) {
        try {
          if ((await stat(match)).isFile()) {
            found.add(match);
          }
        } catch {
          // Absent matches stay silent.
        }
      }
    } catch {
      // Bad patterns stay silent.
    }
  }
  return [...found].sort();
}

// Extract plain text from one history message.
function messageText(message) {
  if (!message || typeof message !== "object") {
    return "";
  }
  if (typeof message.text === "string") {
    return message.text;
  }
  const content = message.content;
  if (typeof content === "string") {
    return content;
  }
  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (typeof part === "string") {
          return part;
        }
        if (part && typeof part.text === "string") {
          return part.text;
        }
        return "";
      })
      .join("\n");
  }
  return "";
}

// Resolve the project root for one session.
async function projectRoot(ctx, sessionID) {
  try {
    const info = await ctx.session.get({ sessionID });
    const directory = info && info.location && info.location.directory;
    if (typeof directory === "string" && directory) {
      return directory;
    }
  } catch {
    // Fall through to the process directory below.
  }
  return process.cwd();
}

// Seed per-session state from the transcript for later prompts.
async function ensureSeeded(ctx, state, sessionID) {
  if (state.seeded.has(sessionID)) {
    return;
  }
  state.seeded.add(sessionID);
  let messages;
  try {
    messages = await ctx.session.context({ sessionID });
  } catch {
    return;
  }
  if (!Array.isArray(messages)) {
    return;
  }
  for (const message of messages) {
    if (messageText(message).includes(MANIFEST_TAG)) {
      state.rootDone.add(sessionID);
    }
  }
}

export default {
  id: "jpenv-agents",
  setup: async (ctx) => {
    const state = { seeded: new Set(), rootDone: new Set(), injected: new Map() };

    // Announce root matches as a chat message for the model to read.
    await ctx.session.hook("prompt", async (event) => {
      const sessionID = event.sessionID;
      await ensureSeeded(ctx, state, sessionID);
      if (state.rootDone.has(sessionID)) {
        return;
      }
      state.rootDone.add(sessionID);
      const root = await projectRoot(ctx, sessionID);
      const matches = await expandPatterns(await readPatterns(root), root);
      if (!matches.length) {
        return;
      }
      let seen = state.injected.get(sessionID);
      if (!seen) {
        seen = new Set();
        state.injected.set(sessionID, seen);
      }
      const fresh = matches.filter((file) => !seen.has(file));
      if (!fresh.length) {
        return;
      }
      for (const file of fresh) {
        seen.add(file);
      }
      await announce(ctx, sessionID, fresh);
    });

    // Direct the model to sibling matches when a file tool runs.
    await ctx.tool.hook("execute.before", async (event) => {
      if (event.tool !== "read" && event.tool !== "edit" && event.tool !== "write") {
        return;
      }
      const input = event.input && typeof event.input === "object" ? event.input : undefined;
      const raw = input && (input.filePath ?? input.file_path ?? input.path ?? input.file);
      if (typeof raw !== "string" || !raw) {
        return;
      }
      const sessionID = event.sessionID;
      await ensureSeeded(ctx, state, sessionID);
      const root = await projectRoot(ctx, sessionID);
      const patterns = await readPatterns(root);
      if (!patterns.length) {
        return;
      }
      const absolute = path.isAbsolute(raw) ? raw : path.join(root, raw);
      const matches = await expandPatterns(patterns, path.dirname(absolute));
      let seen = state.injected.get(sessionID);
      if (!seen) {
        seen = new Set();
        state.injected.set(sessionID, seen);
      }
      const fresh = matches.filter((file) => !seen.has(file));
      if (!fresh.length) {
        return;
      }
      for (const file of fresh) {
        seen.add(file);
      }
      await announce(ctx, sessionID, fresh);
    });

    return () => {};
  },
};
