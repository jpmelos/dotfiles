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
            on_select = {
                move_to_front = true,
                close_telescope = true,
            },
            keys = {
                telescope = {
                    i = {
                        --- It is possible to map to more than one key.
                        -- select = { '<CR>', '<C-C>' }
                        select = "<CR>",
                        delete = "<C-D>", -- delete an entry
                        edit = "<C-E>", -- edit an entry
                        paste = "<NOP>",
                        paste_behind = "<NOP>",
                        replay = "<NOP>",
                    },
                    n = {
                        select = "<CR>",
                        delete = "D",
                        edit = "E",
                        paste = "<NOP>",
                        paste_behind = "<NOP>",
                        replay = "<NOP>",
                    },
                },
            },
        })

        K(
            "n",
            "<leader>fy",
            "<cmd>Telescope neoclip<cr>",
            { desc = "Find yanked values" }
        )
    end,
}
