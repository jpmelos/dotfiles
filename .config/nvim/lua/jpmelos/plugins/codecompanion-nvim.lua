return {
    "olimorris/codecompanion.nvim",
    enabled = false,
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
        "github/copilot.vim",
        "Davidyz/VectorCode",
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
                    tools = {
                        vectorcode = {
                            description = "Run VectorCode to retrieve the project context.",
                            callback = require("vectorcode.integrations").codecompanion.chat.make_tool({
                                auto_submit = { ls = true, query = true },
                            }),
                        },
                    },
                },
            },
        })
    end,
}
