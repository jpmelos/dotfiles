import { Plugin } from "@opencode/plugin/tui"
import { readFile } from "node:fs/promises"
import { homedir } from "node:os"
import path from "node:path"

type FastPermission = {
  name: string
  action: string
  resource: string
}

type SessionRule = {
  action: string
  resource: string
  effect: "allow" | "deny" | "ask"
}

// One entry of the toggle list from the profile config file.
function isFastPermission(value: unknown): value is FastPermission {
  if (typeof value !== "object" || value === null) return false
  const entry = value as Record<string, unknown>
  return (
    typeof entry.name === "string" &&
    entry.name.length > 0 &&
    typeof entry.action === "string" &&
    entry.action.length > 0 &&
    typeof entry.resource === "string" &&
    entry.resource.length > 0
  )
}

// The toggle list lives under `jpenv.fast_permissions` in the profile file.
async function loadFastPermissions(): Promise<FastPermission[]> {
  const configPath = path.join(homedir(), ".config", "opencode", "opencode.json")
  const raw = await readFile(configPath, "utf8")
  const parsed: unknown = JSON.parse(raw)
  if (typeof parsed !== "object" || parsed === null) return []
  const section: unknown = (parsed as { jpenv?: unknown }).jpenv
  if (typeof section !== "object" || section === null) return []
  const list: unknown = (section as { fast_permissions?: unknown }).fast_permissions
  if (Array.isArray(list) === false) return []
  return (list as unknown[]).filter(isFastPermission)
}

// Identity is the exact `action` plus the exact `resource`.
function findRuleIndex(rules: readonly SessionRule[], entry: FastPermission): number {
  return rules.findIndex((rule) => rule.action === entry.action && rule.resource === entry.resource)
}

// Allows armed before any session exists. They apply to the next session.
type PendingAllows = {
  list: () => FastPermission[]
  add: (entry: FastPermission) => void
  remove: (entry: FastPermission) => void
  clear: () => void
}

// Adds one allow rule per entry, unless one already allows it.
function mergeAllows(currentRules: SessionRule[], entries: readonly FastPermission[]): void {
  for (const entry of entries) {
    const ruleIndex = findRuleIndex(currentRules, entry)
    if (ruleIndex === -1) {
      currentRules.push({ action: entry.action, resource: entry.resource, effect: "allow" })
    } else if (currentRules[ruleIndex]?.effect !== "allow") {
      currentRules[ruleIndex] = { action: entry.action, resource: entry.resource, effect: "allow" }
    }
  }
}

// Target the open session, else the active tab, else the latest session.
function currentSessionID(context: Plugin.Context): string | undefined {
  const route = context.ui.router.current()
  if (route.type === "session") return route.sessionID
  const active = context.ui.tabs.list().find((tab) => tab.active)
  if (active !== undefined) return active.sessionID
  return context.data.session.list()[0]?.id
}

// Toggles one entry for the current session.
async function toggleFastPermission(context: Plugin.Context, pending: PendingAllows): Promise<void> {
  let entries: FastPermission[]
  try {
    entries = await loadFastPermissions()
  } catch {
    context.ui.toast.show({ message: "Fast permissions config is unreadable.", variant: "error" })
    return
  }
  if (entries.length === 0) {
    context.ui.toast.show({ message: "No fast permissions in config.", variant: "warning" })
    return
  }
  const sessionID = currentSessionID(context)
  if (sessionID === undefined) {
    await togglePending(context, pending, entries)
    return
  }
  let info
  try {
    info = await context.client.session.get({ sessionID })
  } catch {
    context.ui.toast.show({ message: "Session is unreadable.", variant: "error" })
    return
  }
  const currentRules: SessionRule[] = [...(info.permissions ?? [])]
  const armed = pending.list()
  if (armed.length > 0) {
    mergeAllows(currentRules, armed)
    pending.clear()
  }
  const selected = await context.ui.dialog.select({
    title: "Fast permissions",
    options: entries.map((entry, index) => {
      const ruleIndex = findRuleIndex(currentRules, entry)
      const enabled = ruleIndex !== -1 && currentRules[ruleIndex]?.effect === "allow"
      return {
        title: `${enabled ? "🟢" : "🔴"} ${entry.name} (${entry.action}: ${entry.resource})`,
        value: index,
      }
    }),
  })
  if (selected === undefined) return
  const chosen = entries[selected]
  if (chosen === undefined) return
  const ruleIndex = findRuleIndex(currentRules, chosen)
  let nextEffect: "allow" | "deny"
  if (ruleIndex === -1) {
    nextEffect = "allow"
    currentRules.push({ action: chosen.action, resource: chosen.resource, effect: nextEffect })
  } else {
    nextEffect = currentRules[ruleIndex]?.effect === "allow" ? "deny" : "allow"
    currentRules[ruleIndex] = { action: chosen.action, resource: chosen.resource, effect: nextEffect }
  }
  try {
    await context.client.session.update({ sessionID, permissions: currentRules })
  } catch {
    context.ui.toast.show({ message: "Session update failed.", variant: "error" })
    return
  }
  context.ui.toast.show({
    message: `${chosen.name} is now ${nextEffect === "allow" ? "enabled" : "disabled"}.`,
    variant: "success",
  })
}

// Arms one allow for the next session, while none exists yet.
async function togglePending(context: Plugin.Context, pending: PendingAllows, entries: FastPermission[]): Promise<void> {
  const armed = pending.list()
  const selected = await context.ui.dialog.select({
    title: "Fast permissions",
    options: entries.map((entry, index) => {
      const on = armed.some((item) => item.action === entry.action && item.resource === entry.resource)
      return {
        title: `${on ? "🟢" : "🔴"} ${entry.name} (${entry.action}: ${entry.resource})`,
        value: index,
      }
    }),
  })
  if (selected === undefined) return
  const chosen = entries[selected]
  if (chosen === undefined) return
  const on = pending.list().some((item) => item.action === chosen.action && item.resource === chosen.resource)
  if (on) {
    pending.remove(chosen)
    context.ui.toast.show({ message: `${chosen.name} stays off.`, variant: "success" })
    return
  }
  pending.add(chosen)
  context.ui.toast.show({ message: `${chosen.name} turns on with the next session.`, variant: "success" })
}

// Disables every enabled entry for the current session.
async function disableAllFastPermissions(context: Plugin.Context, pending: PendingAllows): Promise<void> {
  let entries: FastPermission[]
  try {
    entries = await loadFastPermissions()
  } catch {
    context.ui.toast.show({ message: "Fast permissions config is unreadable.", variant: "error" })
    return
  }
  if (entries.length === 0) {
    context.ui.toast.show({ message: "No fast permissions in config.", variant: "warning" })
    return
  }
  const armed = pending.list()
  const sessionID = currentSessionID(context)
  if (sessionID === undefined) {
    if (armed.length === 0) {
      context.ui.toast.show({ message: "No fast permissions enabled.", variant: "warning" })
      return
    }
    pending.clear()
    const list = armed.map(rowLabel).join(", ")
    context.ui.toast.show({ message: `Disabled fast permissions: ${list}.`, variant: "success" })
    return
  }
  let info
  try {
    info = await context.client.session.get({ sessionID })
  } catch {
    context.ui.toast.show({ message: "Session is unreadable.", variant: "error" })
    return
  }
  const currentRules: SessionRule[] = [...(info.permissions ?? [])]
  pending.clear()
  const enabled = entries.filter((entry) => isRuleEnabled(currentRules, entry))
  const disabled: FastPermission[] = [...enabled]
  for (const entry of armed) {
    const known = disabled.some((item) => item.action === entry.action && item.resource === entry.resource)
    if (known === false) disabled.push(entry)
  }
  if (disabled.length === 0) {
    context.ui.toast.show({ message: "No fast permissions enabled.", variant: "warning" })
    return
  }
  if (enabled.length > 0) {
    for (const entry of enabled) {
      const ruleIndex = findRuleIndex(currentRules, entry)
      if (ruleIndex !== -1) {
        currentRules[ruleIndex] = { action: entry.action, resource: entry.resource, effect: "deny" }
      }
    }
    try {
      await context.client.session.update({ sessionID, permissions: currentRules })
    } catch {
      context.ui.toast.show({ message: "Session update failed.", variant: "error" })
      return
    }
  }
  const list = disabled.map(rowLabel).join(", ")
  context.ui.toast.show({ message: `Disabled fast permissions: ${list}.`, variant: "success" })
}

// An entry counts as enabled when its rule allows it.
function isRuleEnabled(rules: readonly SessionRule[], entry: FastPermission): boolean {
  const ruleIndex = findRuleIndex(rules, entry)
  return ruleIndex !== -1 && rules[ruleIndex]?.effect === "allow"
}

// One row as `<name> (<action>: <resource>)`.
function rowLabel(entry: FastPermission): string {
  return `${entry.name} (${entry.action}: ${entry.resource})`
}

// Text of the reminder for the enabled entries.
function reminderText(enabled: readonly FastPermission[]): string {
  const list = enabled.map(rowLabel).join(", ")
  return `Fast permissions still on for next turn: ${list}. Run /fp to turn off.`
}

// Logs the enabled entries to the chat after a turn, unless none are on.
async function remindForSession(
  context: Plugin.Context,
  sessionID: string,
  active: Set<string>,
): Promise<void> {
  if (active.has(sessionID)) return
  active.add(sessionID)
  try {
    let info
    try {
      info = await context.client.session.get({ sessionID })
    } catch {
      return
    }
    // A child session names its parent, so subagents stay silent.
    if (info?.parentID) return
    let entries: FastPermission[]
    try {
      entries = await loadFastPermissions()
    } catch {
      return
    }
    if (entries.length === 0) return
    const currentRules: SessionRule[] = [...(info.permissions ?? [])]
    const enabled = entries.filter((entry) => isRuleEnabled(currentRules, entry))
    if (enabled.length === 0) return
    const text = reminderText(enabled)
    try {
      await context.client.session.synthetic({ sessionID, text, description: text, resume: false })
    } catch {
      context.ui.toast.show({ message: text, variant: "warning" })
    }
  } finally {
    active.delete(sessionID)
  }
}

// Applies armed allows to a new session, then disarms them.
async function applyPending(context: Plugin.Context, pending: PendingAllows, sessionID: string): Promise<void> {
  const armed = pending.list()
  if (armed.length === 0) return
  let info
  try {
    info = await context.client.session.get({ sessionID })
  } catch {
    return
  }
  const currentRules: SessionRule[] = [...(info.permissions ?? [])]
  mergeAllows(currentRules, armed)
  try {
    await context.client.session.update({ sessionID, permissions: currentRules })
  } catch {
    context.ui.toast.show({ message: "Pending permissions failed.", variant: "error" })
    return
  }
  pending.clear()
  context.ui.toast.show({ message: "Fast permissions applied.", variant: "success" })
}

export default Plugin.define({
  id: "jpenv.fast-permissions",
  setup: async (context) => {
    const [pendingStore, setPendingStore] = context.storage.memory<{ entries: FastPermission[] }>("pending", {
      initial: { entries: [] },
    })
    const pending: PendingAllows = {
      list: () => [...pendingStore.entries],
      add: (entry) =>
        setPendingStore((draft) => {
          const known = draft.entries.some((item) => item.action === entry.action && item.resource === entry.resource)
          if (known === false) draft.entries.push({ ...entry })
        }),
      remove: (entry) =>
        setPendingStore((draft) => {
          draft.entries = draft.entries.filter((item) => item.action !== entry.action || item.resource !== entry.resource)
        }),
      clear: () =>
        setPendingStore((draft) => {
          draft.entries = []
        }),
    }
    const off = context.data.on("session.created", (event) => {
      void applyPending(context, pending, event.data.sessionID).catch(() => {
        context.ui.toast.show({ message: "Pending permissions failed.", variant: "error" })
      })
    })
    const reminding = new Set<string>()
    const offSucceeded = context.data.on("session.execution.succeeded", (event) => {
      void remindForSession(context, event.data.sessionID, reminding).catch(() => {})
    })
    const offFailed = context.data.on("session.execution.failed", (event) => {
      void remindForSession(context, event.data.sessionID, reminding).catch(() => {})
    })
    const offInterrupted = context.data.on("session.execution.interrupted", (event) => {
      void remindForSession(context, event.data.sessionID, reminding).catch(() => {})
    })
    context.keymap.layer(() => ({
      mode: "global",
      commands: [
        {
          id: "jpenv.fast-permissions",
          title: "Fast permissions",
          description: "Toggle one session permission from the config list.",
          slash: { name: "fp" },
          run: async () => {
            await toggleFastPermission(context, pending)
          },
        },
        {
          id: "jpenv.fast-permissions-disable-all",
          title: "Disable all fast permissions",
          description: "Disable all enabled permissions from the config list.",
          slash: { name: "fpd" },
          run: async () => {
            await disableAllFastPermissions(context, pending)
          },
        },
      ],
    }))
    return () => {
      off()
      offSucceeded()
      offFailed()
      offInterrupted()
    }
  },
})
