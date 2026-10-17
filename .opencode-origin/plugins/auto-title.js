// Name the session from the full transcript after each response.
// The title model and the length cap come from `jpenv.auto_title` in the
// profile config. A failure leaves the current title alone.
// Subagent child sessions stay silent.
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import path from "node:path";

// This bound caps the history text in the title request.
const HISTORY_LIMIT = 24000;
const FALLBACK_MODEL = "opencode-go/claude-haiku-5-5";
const FALLBACK_MAX_LENGTH = 60;

// This is the path of the profile config inside the container.
function configPath() {
  return path.join(homedir(), ".config", "opencode", "opencode.json");
}

// This returns the title settings with safe defaults.
async function loadAutoTitle() {
  const fallback = { enabled: true, model: FALLBACK_MODEL, maxLength: FALLBACK_MAX_LENGTH };
  let parsed;
  try {
    parsed = JSON.parse(await readFile(configPath(), "utf8"));
  } catch {
    return fallback;
  }
  if (typeof parsed !== "object" || parsed === null) return fallback;
  const section = parsed.jpenv?.auto_title;
  if (typeof section !== "object" || section === null) return fallback;
  const enabled = section.enabled !== false;
  const model = typeof section.model === "string" && section.model ? section.model : FALLBACK_MODEL;
  let maxLength = FALLBACK_MAX_LENGTH;
  if (typeof section.max_length === "number" && Number.isFinite(section.max_length)) {
    maxLength = Math.floor(section.max_length);
    if (maxLength < 20 || maxLength > 200) maxLength = FALLBACK_MAX_LENGTH;
  }
  return { enabled, model, maxLength };
}

// This splits a `provider/model#variant` ref into client parts.
function parseModelRef(value) {
  if (typeof value !== "string") return undefined;
  const base = value.split("#")[0];
  const slash = base.indexOf("/");
  if (slash === -1) return undefined;
  const providerID = base.slice(0, slash).trim();
  const id = base.slice(slash + 1).trim();
  if (!providerID || !id) return undefined;
  return { providerID, id };
}

// This reads the model of the active session.
function modelFromSession(info) {
  if (!info || typeof info !== "object") return undefined;
  if (typeof info.model === "string") return parseModelRef(info.model);
  const ref = info.model;
  if (ref && typeof ref === "object") {
    const providerID = ref.providerID ?? ref.provider;
    const id = ref.id ?? ref.modelID ?? ref.model;
    if (typeof providerID === "string" && typeof id === "string" && providerID && id) {
      return { providerID, id };
    }
  }
  return undefined;
}

// This reads the text of one history message.
function messageText(message) {
  if (!message || typeof message !== "object") return "";
  if (typeof message.text === "string") return message.text;
  const content = message.content ?? message.message?.content;
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .map((part) => {
        if (typeof part === "string") return part;
        if (part && typeof part.text === "string") return part.text;
        return "";
      })
      .join("\n");
  }
  return "";
}

// This reads the role of one history message.
function messageRole(message) {
  if (message && typeof message.role === "string") return message.role;
  if (message?.message && typeof message.message.role === "string") return message.message.role;
  if (message && (message.type === "user" || message.type === "assistant")) return message.type;
  return "unknown";
}

// This trims a raw answer to one line within the cap.
function normalizeTitle(value, maxLength) {
  if (typeof value !== "string") return "";
  let title = value.trim().replace(/^["']+|["']+$/g, "").trim();
  title = title.split("\n")[0].trim().replace(/\s+/g, " ");
  if (title.length > maxLength) title = title.slice(0, maxLength).trim();
  return title.replace(/[.,;:!?-]+$/, "").trim();
}

// This renames the session from its history, latest response included.
async function renameFromHistory(ctx, sessionID) {
  const config = await loadAutoTitle();
  if (config.enabled === false) return;
  let info;
  try {
    info = await ctx.session.get({ sessionID });
  } catch {
    return;
  }
  // A child session names its parent, so subagents stay silent.
  if (info && info.parentID) return;
  let messages;
  try {
    messages = await ctx.session.context({ sessionID });
  } catch {
    return;
  }
  if (!Array.isArray(messages)) return;
  const lines = [];
  for (const message of messages) {
    const role = messageRole(message);
    if (role !== "user" && role !== "assistant" && role !== "unknown") continue;
    const text = messageText(message).trim();
    if (!text) continue;
    lines.push(role + ": " + text);
  }
  // An empty history carries no name.
  if (lines.length === 0) return;
  let history = lines.join("\n\n");
  if (history.length > HISTORY_LIMIT) history = history.slice(-HISTORY_LIMIT);
  const model = parseModelRef(config.model) ?? modelFromSession(info) ?? parseModelRef(FALLBACK_MODEL);
  let answer;
  try {
    answer = await ctx.generate.text({
      model,
      prompt:
        "Write a short session title of 3 to 10 words and at most " +
        config.maxLength +
        " characters for the session below. Reply with the title only and no quotes.\n\n" +
        history,
    });
  } catch {
    return;
  }
  const title = normalizeTitle(typeof answer === "string" ? answer : answer?.text, config.maxLength);
  if (!title) return;
  try {
    await ctx.session.update({ sessionID, title });
  } catch {
    // The session keeps its current title.
  }
}

export default {
  id: "auto-title",
  setup: async (ctx) => {
    const controller = new AbortController();
    void (async () => {
      try {
        for await (const event of ctx.event.subscribe({ signal: controller.signal })) {
          if (event.type !== "session.execution.succeeded") continue;
          void renameFromHistory(ctx, event.data.sessionID).catch(() => {});
        }
      } catch {
        // The subscription ends on unload. Nothing to report.
      }
    })();
    return () => {
      controller.abort();
    };
  },
};
