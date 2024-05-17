return {
    "folke/noice.nvim",
    lazy = false,
    dependencies = {
        "MunifTanjim/nui.nvim",
        "rcarriga/nvim-notify",
        "nvim-treesitter/nvim-treesitter",
        -- For documentation popup.
        "hrsh7th/nvim-cmp",
    },
    config = function()
        local K = vim.keymap.set

        require("noice").setup({
            lsp = {
                -- Override Markdown rendering so that `nvim-cmp` and other
                -- plugins use `nvim-treesitter`.
                override = {
                    ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
                    ["vim.lsp.util.stylize_markdown"] = true,
                    ["cmp.entry.get_documentation"] = true,
                },
            },
            presets = {
                -- Use a classic bottom cmdline for search.
                bottom_search = true,
                -- Position the cmdline and popupmenu together in the command
                -- palette.
                command_palette = true,
                -- Send long messages to a split.
                long_message_to_split = true,
                -- Add a border to hover docs and signature help.
                lsp_doc_border = true,
            },
        })

        K({ "n", "i", "s" }, "<c-f>", function()
            if not require("noice.lsp").scroll(4) then
                return "<C-f>"
            end
        end, { silent = true, expr = true })

        vim.keymap.set({ "n", "i", "s" }, "<c-b>", function()
            if not require("noice.lsp").scroll(-4) then
                return "<C-b>"
            end
        end, { silent = true, expr = true })
    end,
}
