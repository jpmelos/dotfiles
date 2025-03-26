return {
    "rmagatti/auto-session",
    keys = {
        {
            "<leader>wr",
            "<cmd>SessionRestore<CR>",
            desc = "Restore session for current directory",
        },
        {
            "<leader>ws",
            "<cmd>SessionSave<CR>",
            desc = "Save session for current directory",
        },
    },
    opts = {
        -- Automatic behavior.
        enabled = false,
        auto_save = false,
        auto_restore = false,
        auto_create = false,
        -- Do not restore last session if a session for the current
        -- directory can't be found.
        auto_restore_last_session = false,
        -- Do not base sessions on git branches.
        use_git_branch = false,
    },
}
