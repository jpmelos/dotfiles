return {
    "kdheepak/lazygit.nvim",
    cmd = {
        "LazyGit",
        "LazyGitConfig",
        "LazyGitCurrentFile",
        "LazyGitFilter",
        "LazyGitFilterCurrentFile",
    },
    -- For floating window border decoration.
    dependencies = { "nvim-lua/plenary.nvim" },
    -- Load the plugin when this keybinding is used.
    keys = { { "<leader>lg", "<cmd>LazyGit<cr>", desc = "Open lazygit" } },
}
