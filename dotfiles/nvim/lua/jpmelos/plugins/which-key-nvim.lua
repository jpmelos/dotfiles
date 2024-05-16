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

        wk.register({
            w = "+ Sessions",
            p = "+ Format",
            l = "+ Lint",
            c = "+ Code actions",
            g = "+ Git",
            m = "+ Markdown",
            f = "+ Finder",
            e = "+ Explorer",
            x = "+ Quickfix",
            s = "+ Splits",
            t = "+ Tabs",
        }, { prefix = "<leader>" })
    end,
}
