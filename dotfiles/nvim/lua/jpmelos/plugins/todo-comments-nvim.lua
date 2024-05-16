return {
    "folke/todo-comments.nvim",
    lazy = false,
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
        local K = vim.keymap.set

        local todo_comments = require("todo-comments")

        K("n", "]c", function()
            todo_comments.jump_next()
        end, { desc = "Next todo comment" })
        K("n", "[c", function()
            todo_comments.jump_prev()
        end, { desc = "Previous todo comment" })

        todo_comments.setup()
    end,
}
