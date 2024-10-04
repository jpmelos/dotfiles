return {
    "folke/which-key.nvim",
    lazy = false,
    init = function()
        vim.o.timeout = true
        vim.o.timeoutlen = 500
    end,
    config = function()
        require("which-key").setup({
            win = { border = "rounded" },
            keys = {
                scroll_down = "<C-d>",
                scroll_up = "<C-f>",
            },
            spec = {
                { "gp", group = "LSP previews" },
                { "<leader>b", group = "+ Current buffer" },
                { "<leader>c", group = "+ Code actions" },
                { "<leader>d", group = "+ Debug" },
                { "<leader>dp", group = "+ Python" },
                { "<leader>e", group = "+ Explorer" },
                { "<leader>f", group = "+ Finder" },
                { "<leader>g", group = "+ Git" },
                { "<leader>l", group = "+ LSP/Lint" },
                { "<leader>m", group = "+ Markdown" },
                { "<leader>o", group = "+ Obsidian" },
                { "<leader>p", group = "+ Format" },
                { "<leader>r", group = "+ Requests" },
                { "<leader>s", group = "+ Splits" },
                { "<leader>t", group = "+ Tabs" },
                { "<leader>v", group = "+ Database" },
                { "<leader>w", group = "+ Sessions" },
                { "<leader>x", group = "+ Quickfix" },
            },
        })
    end,
}
