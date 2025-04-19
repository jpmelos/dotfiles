-- For things to work properly with project context, make sure ChromaDB is
-- running with:
-- ```
-- docker run -d -v $HOME/chroma-data:/data -p 8000:8000 --name chroma \
--     chromadb/chroma:0.6.3
-- ```
-- There is a bash function for this named `vecdb`.
--
-- Make sure the version of VectorCode always matches the version installed
-- with pipx.
--
-- Make sure to always vectorise the project with:
-- ```
-- vectorcode init; vectorcode vectorise --include-hidden -r .
-- ```
-- This is alised as `vec`.
return {
    "olimorris/codecompanion.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-treesitter/nvim-treesitter",
        "hrsh7th/nvim-cmp",
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
        {
            "<leader>aa",
            "<cmd>CodeCompanionChat Add<cr>",
            mode = "v",
            desc = "Open AI chat, send selection",
        },
    },
    config = function()
        local vectorcode_make_tool =
            require("vectorcode.integrations").codecompanion.chat.make_tool

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
                            description = "Run VectorCode to retrieve the"
                                .. " project context.",
                            callback = vectorcode_make_tool({
                                auto_submit = { ls = true, query = true },
                            }),
                        },
                    },
                },
            },
        })
    end,
}
