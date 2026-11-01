// Announce the files that `jpenv-agents.json` names.
//
// The settings hook prints a read directive silently. This mod logs one
// manifest per load, like the `fp` reminder, so the transcript shows
// which files the session must read. The model never reads these lines.

const CONFIG_NAME = "jpenv-agents.json";
const MANIFEST_TAG = "jpenv-agents manifest";
const READ_TOOLS = ["Read", "Edit", "Write"];

// Files with a logged manifest in this process.
const siblingSeen = new Set();

// Log one manifest line per file.
function announceManifest($, files) {
  $.ui.log(MANIFEST_TAG + " (" + files.length + " files):");
  for (const file of files) {
    $.ui.log("- " + file);
  }
}

// Read the pattern list at the working directory.
async function readPatterns($) {
  let parsed;
  try {
    parsed = JSON.parse(await $.fs.read(CONFIG_NAME));
  } catch {
    return [];
  }
  if (parsed === null || typeof parsed !== "object") {
    return [];
  }
  if (Array.isArray(parsed.context) === false) {
    return [];
  }
  return parsed.context.filter(
    (entry) => typeof entry === "string" && entry.length > 0,
  );
}

// Join path parts with one slash.
function joinPath(base, name) {
  if (base === "" || base === "/") {
    return "/" + name;
  }
  if (base === ".") {
    return name;
  }
  return base + "/" + name;
}

// Split one path into segments without empty parts.
function splitPath(value) {
  return value.split("/").filter((part) => part.length > 0);
}

// Match one path segment with `*` and `?` wildcards.
function matchSegment(pattern, name) {
  let source = "";
  for (const char of pattern) {
    if (char === "*") {
      source += "[^/]*";
    } else if (char === "?") {
      source += "[^/]";
    } else {
      source += char.replace(/[.+^${}()|[\]\\]/, "\\$&");
    }
  }
  return new RegExp("^" + source + "$").test(name);
}

// List one directory.
async function listDir($, dir) {
  try {
    const entries = await $.fs.list(dir === "" ? "/" : dir);
    return Array.isArray(entries) ? entries : [];
  } catch {
    return [];
  }
}

// Collect every directory under the given bases.
async function collectDirs($, bases) {
  const found = [];
  const seen = new Set(bases);
  const queue = bases.slice();
  for (const base of bases) {
    found.push(base);
  }
  while (queue.length > 0) {
    const dir = queue.pop();
    const entries = await listDir($, dir);
    for (const entry of entries) {
      if (!entry || typeof entry.name !== "string") {
        continue;
      }
      const full = joinPath(dir, entry.name);
      if (seen.has(full)) {
        continue;
      }
      seen.add(full);
      const listed = await listDir($, full);
      const isDir = entry.kind === "dir" || entry.kind === "directory";
      if (listed.length > 0 || isDir) {
        found.push(full);
        queue.push(full);
      }
    }
  }
  return found;
}

// Expand patterns from the working directory into sorted file paths.
async function expandPatterns($, patterns, base) {
  const found = new Set();
  for (const pattern of patterns) {
    const absolute = pattern.startsWith("/");
    const segments = splitPath(pattern);
    if (segments.length === 0) {
      continue;
    }
    let dirs = [absolute ? "" : base];
    for (let index = 0; index < segments.length; index++) {
      const last = index === segments.length - 1;
      if (segments[index] === "**") {
        dirs = await collectDirs($, dirs);
        continue;
      }
      const next = [];
      for (const dir of dirs) {
        const entries = await listDir($, dir);
        for (const entry of entries) {
          if (!entry || typeof entry.name !== "string") {
            continue;
          }
          if (matchSegment(segments[index], entry.name) === false) {
            continue;
          }
          const full = joinPath(dir, entry.name);
          if (last) {
            if (entry.kind === "file") {
              found.add(full);
            } else {
              try {
                await $.fs.read(full);
                found.add(full);
              } catch {
                // Absent paths and directories stay silent.
              }
            }
          } else if (next.includes(full) === false) {
            next.push(full);
          }
        }
      }
      dirs = next;
    }
  }
  return [...found].sort();
}

// Resolve the project root through the process working directory.
async function projectRoot($) {
  try {
    const run = await $.process.run(["pwd"]);
    const dir = typeof run.stdout === "string" ? run.stdout.trim() : "";
    if (run.exitCode === 0 && dir) {
      return dir;
    }
  } catch {
    // Fall through to relative paths below.
  }
  return "";
}

// Report whether the transcript already shows a manifest line.
async function hasManifest($) {
  let messages;
  try {
    messages = await $.session.messages();
  } catch {
    return false;
  }
  if (Array.isArray(messages) === false) {
    return false;
  }
  return messages.some(hasManifestLine);
}

// Report whether one message shows a manifest line.
function hasManifestLine(message) {
  if (!message || typeof message.text !== "string") {
    return false;
  }
  return message.text.includes(MANIFEST_TAG);
}

// Drop the last segment of one path.
function dirName(value) {
  const parts = splitPath(value);
  parts.pop();
  const rest = parts.join("/");
  if (value.startsWith("/")) {
    return "/" + rest;
  }
  return rest === "" ? "." : rest;
}

export function register(on) {
  on("session.start", async ($, e, next) => {
    siblingSeen.clear();
    try {
      if ((await hasManifest($)) === false) {
        const root = await projectRoot($);
        const base = root === "" ? "." : root;
        const files = await expandPatterns($, await readPatterns($), base);
        if (files.length > 0) {
          for (const file of files) {
            siblingSeen.add(file);
          }
          announceManifest($, files);
        }
      }
    } catch {
      // The manifest is best-effort. A failure never stops the session.
    }
    return next(e);
  });

  on("tool.call", { tool: READ_TOOLS }, async ($, e, next) => {
    const result = await next(e);
    try {
      const raw = e.file_path;
      if (typeof raw === "string" && raw.length > 0) {
        const root = await projectRoot($);
        const base = raw.startsWith("/")
          ? raw
          : joinPath(root === "" ? "." : root, raw);
        const patterns = await readPatterns($);
        const matches = await expandPatterns($, patterns, dirName(base));
        const fresh = matches.filter(
          (file) => siblingSeen.has(file) === false,
        );
        for (const file of fresh) {
          siblingSeen.add(file);
        }
        if (fresh.length > 0) {
          announceManifest($, fresh);
        }
      }
    } catch {
      // The manifest is best-effort. A failure never stops the session.
    }
    return result;
  });
}
