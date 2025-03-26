-- To configure this plugin, set the following in the project's `nvim.lua`
-- file:
-- ```
-- vim.g.augment_workspace_folders = { vim.fn.getcwd() }
-- ```
return {
    "augmentcode/augment.vim",
    cmd = { "Augment" },
    init = function()
        local g = vim.g
        local K = vim.keymap.set

        g.augment_disable_tab_mapping = true
        g.augment_disable_completions = true
        g.augment_suppress_version_warning = true

        K("n", "<leader>a", "<cmd>Augment chat<CR>", { desc = "AI chat" })
    end,
}
