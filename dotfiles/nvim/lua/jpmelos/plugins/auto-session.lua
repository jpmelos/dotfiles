return {
    "rmagatti/auto-session",
    config = function()
        local auto_session = require("auto-session")

        auto_session.setup({
            auto_session_enable_last_session = false,
            auto_session_enabled = true,
            auto_session_create_enabled = true,
            auto_save_enabled = true,
            auto_restore_enabled = false,
            auto_session_use_git_branch = false,
            auto_session_allowed_dirs = { "~/devel/*" },
            cwd_change_handling = {
                -- Do not restore session when changing working directory
                -- inside Vim, like with `:cd`.
                restore_upcoming_session = false,
            },
        })

        local keymap = vim.keymap

        keymap.set(
            "n",
            "<leader>wr",
            "<cmd>SessionRestore<CR>",
            { desc = "Restore session for current directory" }
        )
        keymap.set(
            "n",
            "<leader>ws",
            "<cmd>SessionSave<CR>",
            { desc = "Save session for current directory" }
        )
    end,
}
