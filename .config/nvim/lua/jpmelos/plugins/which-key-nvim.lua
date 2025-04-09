return {
    "folke/which-key.nvim",
    priority = 999, -- Load right after the colorscheme.
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
                { "cr", group = "Change base" },
                { "gb", group = "Toggle comments, block-style" },
                { "gc", group = "Toggle comments" },
                { "gp", group = "LSP previews" },
                { "<leader>a", group = "+ AI" },
                { "<leader>b", group = "+ Current buffer" },
                { "<leader>c", group = "+ Code actions" },
                { "<leader>d", group = "+ Debug" },
                { "<leader>e", group = "+ Explorer" },
                { "<leader>f", group = "+ Finder" },
                { "<leader>fc", group = "+ Find under cursor" },
                { "<leader>g", group = "+ Git" },
                { "<leader>l", group = "+ LSP/Lint" },
                { "<leader>m", group = "+ Markdown" },
                { "<leader>o", group = "+ Obsidian" },
                { "<leader>p", group = "+ Format" },
                { "<leader>q", group = "+ Quickfix" },
                { "<leader>r", group = "+ Requests" },
                { "<leader>s", group = "+ Splits" },
                { "<leader>t", group = "+ Tabs" },
                { "<leader>v", group = "+ Database" },
                { "<leader>w", group = "+ Sessions" },
                { "<leader>x", group = "+ Diff" },
            },
        })
    end,
}
