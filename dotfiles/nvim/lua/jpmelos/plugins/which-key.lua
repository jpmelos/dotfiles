return {
    "folke/which-key.nvim",
    event = "VeryLazy",
    init = function()
        vim.o.timeout = true
        vim.o.timeoutlen = 500
    end,
    opts = {
        -- Empty so it uses the default configuration, but leave it here to
        -- make sure lazy initializes the plugin.
    },
}
