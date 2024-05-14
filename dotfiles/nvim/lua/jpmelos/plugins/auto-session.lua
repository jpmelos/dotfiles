return {
    "rmagatti/auto-session",
    lazy = false,
    config = function()
        local K = vim.keymap.set

        require("auto-session").setup({
            auto_session_enable_last_session = false,
            auto_session_enabled = false,
            auto_session_create_enabled = false,
            auto_save_enabled = false,
            auto_restore_enabled = false,
            auto_session_use_git_branch = false,
            auto_session_allowed_dirs = { "~/devel/*" },
            cwd_change_handling = {
                -- Do not restore session when changing working directory
                -- inside Vim, like with `:cd`.
                restore_upcoming_session = false,
            },
        })

        K(
            "n",
            "<leader>wr",
            "<cmd>SessionRestore<CR>",
            { desc = "Restore session for current directory" }
        )
        K(
            "n",
            "<leader>ws",
            "<cmd>SessionSave<CR>",
            { desc = "Save session for current directory" }
        )
    end,
}
