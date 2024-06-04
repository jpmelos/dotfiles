return {
    "folke/trouble.nvim",
    lazy = false,
    dependencies = {
        "nvim-tree/nvim-web-devicons",
        "folke/todo-comments.nvim",
    },
    keys = {
        {
            "<leader>xx",
            "<cmd>TroubleToggle quickfix<CR>",
            desc = "Open/close quickfix list",
        },
        {
            "<leader>xt",
            "<cmd>TodoTrouble<CR>",
            desc = "Open todos in quickfix list",
        },
    },
    opts = {},
}
