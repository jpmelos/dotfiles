return {
    "folke/trouble.nvim",
    dependencies = {
        "nvim-tree/nvim-web-devicons",
        "folke/todo-comments.nvim",
    },
    keys = {
        {
            "<leader>xs",
            "<cmd>Trouble symbols toggle focus=false<cr>",
            desc = "Toggle symbols table",
        },
        {
            "<leader>xx",
            "<cmd>Trouble telescope toggle focus=true<cr>",
            desc = "Toggle telescope selected results",
        },
        {
            "<leader>xt",
            "<cmd>Trouble todo toggle focus=true<cr>",
            desc = "Toggle todos in trouble list",
        },
    },
}
