// Fast permissions pane and instant /fp command.
//
// Reads the toggle list from `jpenv.fast_permissions` in the profile
// settings file. Each row toggles its rule between allow and deny. The
// settings watcher applies the change to the running session.

const PANE = "fast-permissions";

// Entries with a non-empty text name and permission.
function validEntries(value) {
  if (Array.isArray(value) === false) return [];
  return value.filter(
    (entry) =>
      entry !== null &&
      typeof entry === "object" &&
      typeof entry.name === "string" &&
      entry.name.length > 0 &&
      typeof entry.permission === "string" &&
      entry.permission.length > 0,
  );
}

// Read the profile settings file with live rule lists attached.
async function readState($) {
  const home = await $.env.get("HOME");
  const file = home + "/.claude/settings.json";
  const settings = JSON.parse(await $.fs.read(file));
  const raw = settings.jpenv;
  const entries = raw !== null && typeof raw === "object" ? validEntries(raw.fast_permissions) : [];
  let permissions = settings.permissions;
  if (permissions === null || typeof permissions !== "object") {
    permissions = {};
    settings.permissions = permissions;
  }
  if (Array.isArray(permissions.allow) === false) permissions.allow = [];
  if (Array.isArray(permissions.deny) === false) permissions.deny = [];
  return { file, settings, entries, allow: permissions.allow, deny: permissions.deny };
}

// An entry counts as enabled only in allow and outside deny.
function isEnabled(state, entry) {
  return state.allow.includes(entry.permission) && state.deny.includes(entry.permission) === false;
}

// One row as `<status> <name> (<permission>)`.
function rowLabel(entry, enabled) {
  return (enabled ? "🟢" : "🔴") + " " + entry.name + " (" + entry.permission + ")";
}

// Flip one entry between allow and deny. Return the new state.
async function flipRule($, entry) {
  const state = await readState($);
  if (isEnabled(state, entry)) {
    state.settings.permissions.allow = state.allow.filter((rule) => rule !== entry.permission);
    if (state.deny.includes(entry.permission) === false) state.deny.push(entry.permission);
    await $.fs.write(state.file, JSON.stringify(state.settings, null, 2) + "\n");
    return false;
  }
  state.settings.permissions.deny = state.deny.filter((rule) => rule !== entry.permission);
  if (state.allow.includes(entry.permission) === false) state.allow.push(entry.permission);
  await $.fs.write(state.file, JSON.stringify(state.settings, null, 2) + "\n");
  return true;
}

// A hotkey per row while keys last. Rows past `z` keep no hotkey.
function hotkeyFor(index) {
  if (index < 9) return String(index + 1);
  const letters = "abcdefghijklmnopqrstuvwxyz";
  if (index - 9 < letters.length) return letters[index - 9];
  return undefined;
}

export function register(on) {
  on("session.start", async ($, e, next) => {
    await $.command.register({
      name: "fp",
      description: "Toggle fast permissions",
      argumentHint: "[name]",
      immediate: true,
    });
    return next(e);
  });

  on("command.run", { command: "fp" }, async ($, e) => {
    const args = e.args.trim();
    if (args === "") {
      await $.ui.open({ id: PANE, title: "Fast permissions", focus: true, closeOnEscape: true });
      return {};
    }
    const state = await readState($);
    const found = state.entries.filter((entry) => entry.name.toLowerCase() === args.toLowerCase());
    if (found.length === 0) {
      const valid = state.entries.map((entry) => entry.name).join(", ");
      return { text: "Unknown entry " + args + ". Valid names: " + valid };
    }
    const enabled = await flipRule($, found[0]);
    return { text: rowLabel(found[0], enabled) };
  });

  on("ui.render", { component: "Pane" }, async ($, e, next) => {
    if (e.requestId !== PANE) return next(e);
    const { Box, Text, Button } = $.ui.resolve(e);
    const state = await readState($);
    if (state.entries.length === 0) {
      return Box({ children: [Text({ children: ["No fast permissions in config."] })] });
    }
    return Box({
      flexDirection: "column",
      children: state.entries.map((entry, index) => {
        const props = {
          key: "fp-" + index,
          label: rowLabel(entry, isEnabled(state, entry)),
          onPress: async () => {
            const enabled = await flipRule($, entry);
            $.ui.toast(rowLabel(entry, enabled));
            $.ui.invalidate("ui.render");
          },
        };
        const hotkey = hotkeyFor(index);
        if (hotkey !== undefined) props.hotkey = hotkey;
        return Button(props);
      }),
    });
  });
}
