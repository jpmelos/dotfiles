return {
    "folke/which-key.nvim",
    lazy = false,
    init = function()
        vim.o.timeout = true
        vim.o.timeoutlen = 500
    end,
    config = function()
        local wk = require("which-key")
        wk.setup()

        wk.register({ gp = "LSP previews" })
        wk.register({
            b = "+ Current buffer",
            c = "+ Code actions",
            d = "+ Debug",
            dp = "+ Python",
            e = "+ Explorer",
            f = "+ Finder",
            g = "+ Git",
            l = "+ LSP/Lint",
            m = "+ Markdown",
            o = "+ Obsidian",
            p = "+ Format",
            s = "+ Splits",
            t = "+ Tabs",
            v = "+ Database",
            w = "+ Sessions",
            x = "+ Quickfix",
        }, { prefix = "<leader>" })

        vim.cmd("hi WhichKeyFloat guibg=#eeeeee")
    end,
}
