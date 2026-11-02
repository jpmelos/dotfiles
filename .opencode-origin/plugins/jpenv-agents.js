// Report how many files `jpenv-agents.json` names.
//
// Each load prints a single line with the file count as a chat
// message. Root loads run with the first prompt of each
// session and combine the `all` and `root` lists. Sibling loads run
// when a file tool runs and expand the `all` list from the directory
// of that file and every parent up to the project root.

import { readFile, stat } from "node:fs/promises";
import path from "node:path";

const CONFIG_NAME = "jpenv-agents.json";

// Build the single line report for one announcement.
function reportLine(files) {
  const count = files.length;
  if (count === 1) {
    return "jpenv-agents: 1 file.";
  }
  return "jpenv-agents: " + count + " files.";
}

// Post one file count as a chat message.
async function announce(ctx, sessionID, files) {
  const text = reportLine(files);
  try {
    await ctx.session.synthetic({ sessionID, text, description: text, resume: false });
  } catch {
    // The report is best-effort. A failure never stops the session.
  }
}

// Read the `all` and `root` pattern lists at the project root.
async function readContexts(root) {
  const empty = { all: [], root: [] };
  let parsed;
  try {
    parsed = JSON.parse(await readFile(path.join(root, CONFIG_NAME), "utf8"));
  } catch {
    return empty;
  }
  if (parsed === null || typeof parsed !== "object") {
    return empty;
  }
  const context = parsed.context;
  if (Array.isArray(context)) {
    return { all: cleanList(context), root: [] };
  }
  if (context === null || typeof context !== "object") {
    return empty;
  }
  return { all: cleanList(context.all), root: cleanList(context.root) };
}

// Keep the non-empty string entries of one list.
function cleanList(value) {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter((entry) => typeof entry === "string" && entry.length > 0);
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

// List the directories from the project root to one directory.
function ancestorDirs(root, start) {
  const top = path.resolve(root);
  const leaf = path.resolve(start);
  if (leaf === top) {
    return [top];
  }
  const prefix = top.endsWith(path.sep) ? top : top + path.sep;
  if (!leaf.startsWith(prefix)) {
    return [leaf];
  }
  const rest = leaf.slice(prefix.length).split(path.sep);
  const dirs = [top];
  let current = top;
  for (const part of rest) {
    current = path.join(current, part);
    dirs.push(current);
  }
  return dirs;
}

// Expand patterns from each directory in one chain into sorted paths.
async function expandPatternsChain(patterns, dirs) {
  const found = new Set();
  for (const dir of dirs) {
    const matches = await expandPatterns(patterns, dir);
    for (const match of matches) {
      found.add(match);
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
    const text = messageText(message);
    // New reports carry the single line prefix. Old reports carry the
    // retired directive or the retired header line.
    if (
      text.includes("jpenv-agents:") ||
      text.includes("Read each listed file in full") ||
      text.includes("jpenv-agents manifest")
    ) {
      state.rootDone.add(sessionID);
    }
  }
}

export default {
  id: "jpenv-agents",
  setup: async (ctx) => {
    const state = { seeded: new Set(), rootDone: new Set(), injected: new Map() };

    // Report root matches as a chat message.
    await ctx.session.hook("prompt", async (event) => {
      const sessionID = event.sessionID;
      await ensureSeeded(ctx, state, sessionID);
      if (state.rootDone.has(sessionID)) {
        return;
      }
      state.rootDone.add(sessionID);
      const root = await projectRoot(ctx, sessionID);
      const contexts = await readContexts(root);
      const combined = [...contexts.all, ...contexts.root];
      const matches = await expandPatterns(combined, root);
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

    // Report sibling matches when a file tool runs.
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
      const contexts = await readContexts(root);
      if (!contexts.all.length) {
        return;
      }
      const absolute = path.isAbsolute(raw) ? raw : path.join(root, raw);
      const dirs = ancestorDirs(root, path.dirname(absolute));
      const matches = await expandPatternsChain(contexts.all, dirs);
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
