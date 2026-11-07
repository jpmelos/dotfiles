import { Plugin } from "@opencode/plugin/tui"

// Show the container name in the footer, next to the work area.
// The launcher sets the name for the container.
export default Plugin.define({
  id: "jpenv.container-name",
  setup: (context) => {
    const containerName = (process.env.AGENT_CONTAINER_NAME ?? "").trim()
    // Without a name there is nothing to show, such as outside a container.
    if (!containerName) {
      return
    }
    const label = `📦 ${containerName}`
    const removePrompt = context.ui.slot({
      append: "prompt.footer.status",
      render: () => <text fg={context.theme.text.muted}>{label}</text>,
    })
    const removeHome = context.ui.slot({
      append: "home.footer.status",
      render: () => <text fg={context.theme.text.muted}>{label}</text>,
    })
    return () => {
      removePrompt()
      removeHome()
    }
  },
})
