return {
    "numToStr/Navigator.nvim",
    config = function()
        local K = vim.keymap.set

        require("Navigator").setup()

        K("n", "<C-h>", "<cmd>NavigatorLeft<cr>")
        K("n", "<C-l>", "<cmd>NavigatorRight<cr>")
        K("n", "<C-k>", "<cmd>NavigatorUp<cr>")
        K("n", "<C-j>", "<cmd>NavigatorDown<cr>")
    end,
}
