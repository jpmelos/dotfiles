return {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
        local K = vim.keymap.set

        local todo_comments = require("todo-comments")

        todo_comments.setup({ signs = false })

        K("n", "]c", todo_comments.jump_next, { desc = "Next todo comment" })
        K(
            "n",
            "[c",
            todo_comments.jump_prev,
            { desc = "Previous todo comment" }
        )
    end,
}
