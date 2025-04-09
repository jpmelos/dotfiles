return {
    "olimorris/codecompanion.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
    },
    keys = {
        {
            "<leader>aa",
            "<cmd>CodeCompanionChat Toggle<cr>",
            mode = "n",
            desc = "Open AI chat",
        },
    },
    config = function()
        require("codecompanion").setup({
            display = {
                chat = {
                    auto_scroll = false,
                    start_in_insert_mode = true,
                },
            },
            strategies = {
                chat = {
                    keymaps = {
                        send = {
                            modes = { n = "<S-Enter>", i = "<S-Enter>" },
                        },
                        close = {
                            modes = { n = "q" },
                        },
                    },
                },
            },
        })

        require("lazy").load({ plugins = { "copilot.vim" } })
    end,
}
