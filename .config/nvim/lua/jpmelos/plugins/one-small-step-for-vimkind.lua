return {
    "jbyuki/one-small-step-for-vimkind",
    keys = {
        {
            "<leader>dn",
            function()
                -- Make sure this host and port matches what's configured for
                -- "nvim-dap".
                require("osv").launch({ port = 8086 })
            end,
            mode = "n",
            desc = "Start Neovim debugger",
        },
    },
}
