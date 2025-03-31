return {
    "folke/todo-comments.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
        { "]c", mode = "n", desc = "Next todo comment" },
        { "[c", mode = "n", desc = "Previous todo comment" },
    },
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
