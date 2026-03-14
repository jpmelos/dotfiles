return {
    "numToStr/Navigator.nvim",
    keys = {
        { "<C-h>", "<cmd>NavigatorLeft<cr>", mode = "n" },
        { "<C-l>", "<cmd>NavigatorRight<cr>", mode = "n" },
        { "<C-k>", "<cmd>NavigatorUp<cr>", mode = "n" },
        { "<C-j>", "<cmd>NavigatorDown<cr>", mode = "n" },
    },
    config = function()
        vim.env.TERM_PROGRAM = "WezTerm"
        require("Navigator").setup({
            mux = require("Navigator.mux.wezterm"):new(),
        })
    end,
}
