return {
    "AckslD/nvim-neoclip.lua",
    dependencies = {
        "nvim-telescope/telescope.nvim",
        "kkharji/sqlite.lua",
    },
    config = function()
        local K = vim.keymap.set

        require("neoclip").setup({
            history = 10000,
            enable_persistent_history = true,
            continuous_sync = true,
            default_register = "+",
        })

        K(
            "n",
            "<leader>fy",
            "<cmd>Telescope neoclip<cr>",
            { desc = "Find yanked values" }
        )
    end,
}
