return {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
        local conform = require("conform")
        conform.setup({
            formatters_by_ft = {},
            format_on_save = function(bufnr)
                -- Disable with a global or buffer-local variable.
                if
                    vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat
                then
                    return
                end
                return { async = true, lsp_fallback = false }
            end,
        })

        -- Use Vim's internal formatter, instead of `conform.nvim`, for `gq`.
        vim.api.nvim_create_autocmd('LspAttach', {
            callback = function(args)
                vim.bo[args.buf].formatexpr = nil
            end,
        })

        vim.api.nvim_create_user_command("Format", function(args)
            local range = nil
            if args.count ~= -1 then
                local end_line = vim.api.nvim_buf_get_lines(
                    0,
                    args.line2 - 1,
                    args.line2,
                    true
                )[1]
                range = {
                    start = { args.line1, 0 },
                    ["end"] = { args.line2, end_line:len() },
                }
            end
            require("conform").format({
                async = true,
                lsp_fallback = false,
                range = range,
            })
        end, { range = true })

        vim.api.nvim_create_user_command("FormatDisable", function(args)
            if args.bang then
                -- FormatDisable! will disable formatting just for this buffer.
                vim.b.disable_autoformat = true
            else
                vim.g.disable_autoformat = true
            end
        end, {
            desc = "Disable autoformat-on-save",
            bang = true,
        })
        vim.api.nvim_create_user_command("FormatEnable", function(args)
            if args.bang then
                -- FormatEnable! will enable formatting just for this buffer.
                vim.b.disable_autoformat = false
            else
                vim.b.disable_autoformat = false
                vim.g.disable_autoformat = false
            end
        end, {
            desc = "Enable autoformat-on-save",
            bang = true,
        })

        vim.keymap.set(
            { "n", "v" },
            "<leader>mp",
            "<cmd>Format<CR>",
            { desc = "Format file (or range in visual mode)" }
        )
        vim.keymap.set(
            { "n" },
            "<leader>md",
            "<cmd>FormatDisable<CR>",
            { desc = "Disable auto-format on save" }
        )
        vim.keymap.set(
            { "n" },
            "<leader>me",
            "<cmd>FormatEnable<CR>",
            { desc = "Enable auto-format on save" }
        )
    end,
}
