return {
    "tpope/vim-fugitive",
    init = function()
        local K = vim.keymap.set

        K("n", "<leader>gb", "<cmd>Git blame<cr>", { desc = "Blame" })
    end,
}
