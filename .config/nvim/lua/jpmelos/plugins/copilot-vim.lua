-- We only use this plugin as a way to sign into GitHub Copilot so we can use
-- `codecompanion.nvim`.
return {
    "github/copilot.vim",
    lazy = true,
    config = function()
        vim.g.copilot_no_tab_map = true
        vim.g.copilot_enabled = false
        vim.g.copilot_filetypes = { ["*"] = false }
    end,
}
