return {
    "sindrets/winshift.nvim",
    lazy = false,
    keys = {
        {
            "<leader>sb",
            "<cmd>WinShift<CR>",
            desc = "Shift windows",
        },
        {
            "<leader>sw",
            "<cmd>WinShift swap<CR>",
            desc = "Swap windows",
        },
    },
}
