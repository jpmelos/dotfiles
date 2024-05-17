return {
    "rcarriga/nvim-notify",
    lazy = false,
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
        local K = vim.keymap.set

        vim.notify = require("notify")

        K(
            "n",
            "<leader>fn",
            "<cmd>Telescope notify<CR>",
            { desc = "Find notifications" }
        )
    end,
}
