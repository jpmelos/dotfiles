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

        wk.add({ { "gp", desc = "LSP previews" } })
        wk.add({
            {
                { "b", desc = "+ Current buffer" },
                { "c", desc = "+ Code actions" },
                { "d", desc = "+ Debug" },
                { "dp", desc = "+ Python" },
                { "e", desc = "+ Explorer" },
                { "f", desc = "+ Finder" },
                { "g", desc = "+ Git" },
                { "l", desc = "+ LSP/Lint" },
                { "m", desc = "+ Markdown" },
                { "o", desc = "+ Obsidian" },
                { "p", desc = "+ Format" },
                { "s", desc = "+ Splits" },
                { "t", desc = "+ Tabs" },
                { "v", desc = "+ Database" },
                { "w", desc = "+ Sessions" },
                { "x", desc = "+ Quickfix" },
            },
        })

        vim.cmd("hi WhichKeyFloat guibg=#eeeeee")
    end,
}
