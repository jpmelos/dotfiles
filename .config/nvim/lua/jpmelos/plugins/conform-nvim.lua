return {
    "stevearc/conform.nvim",
    lazy = false,
    config = function()
        local K = vim.keymap.set

        local conform = require("conform")

        -- Disable autoformat by default. Use repository-local .nvim.lua to
        -- enable it for specific projects.
        vim.g.disable_autoformat = true

        conform.setup({
            -- Use repository-local .nvim.lua to overwrite this for specific
            -- projects. Something like:
            -- ```
            --     local conform = require("conform")
            --     conform.formatters_by_ft = {
            --         python = {
            --             "ruff_fix",
            --             "ruff_organize_imports",
            --             "black",
            --         },
            --     }
            -- ```
            formatters_by_ft = {
                sh = { "shfmt" },
                python = {
                    "ruff_fix",
                    "ruff_organize_imports",
                    "ruff_format",
                },
                lua = { "stylua" },
                rust = { "rustfmt" },
                sql = { "sqlfluff" },
                css = { "prettier" },
                scss = { "prettier" },
                javascript = { "prettier" },
                typescript = { "prettier" },
                yaml = { "prettier" },
                graphql = { "prettier" },
            },
        })

        -- ButWritePost: After saving a buffer.
        -- InsertLeave: Every time we leave insert mode.
        vim.api.nvim_create_autocmd({ "BufWritePost" }, {
            callback = function()
                if not vim.g.nvim_has_focus then
                    return
                end

                -- Disable with a global or buffer-local variable.
                if vim.g.disable_autoformat or vim.b.disable_autoformat then
                    return
                end

                require("conform").format({ async = true })
            end,
        })

        -- TODO: Figure this one out: how is this related to `conform.nvim` if
        -- it acts upon `LspAttach`? Should this be in another file, like the
        -- `lspconfig.nvim` file? Or do we even need this at all?
        --
        -- Use Vim's internal formatter, instead of `conform.nvim`, for `gq`.
        vim.api.nvim_create_autocmd("LspAttach", {
            callback = function(args)
                vim.bo[args.buf].formatexpr = ""
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
            conform.format({
                async = true,
                lsp_format = "never",
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
            desc = "Disable autoformat on save",
            bang = true,
        })
        vim.api.nvim_create_user_command("FormatEnable", function(args)
            if args.bang then
                -- FormatEnable! will enable formatting just for this buffer.
                vim.b.disable_autoformat = false
            else
                vim.g.disable_autoformat = false
            end
        end, {
            desc = "Enable autoformat on save",
            bang = true,
        })
        vim.api.nvim_create_user_command("FormatToggle", function(args)
            if args.bang then
                if vim.b.disable_autoformat then
                    -- FormatEnable! will enable formatting just for this buffer.
                    vim.b.disable_autoformat = false
                else
                    vim.b.disable_autoformat = true
                end
            else
                if vim.g.disable_autoformat then
                    -- FormatEnable! will enable formatting just for this buffer.
                    vim.g.disable_autoformat = false
                else
                    vim.g.disable_autoformat = true
                end
            end
        end, {
            desc = "Toggle autoformat on save",
            bang = true,
        })

        K(
            { "n", "v" },
            "<leader>pf",
            "<cmd>Format<CR>",
            { desc = "Format file (or range in visual mode)" }
        )
        K(
            { "n" },
            "<leader>pt",
            "<cmd>FormatToggle<CR>",
            { desc = "Toggle auto-format on save" }
        )
        K(
            { "n" },
            "<leader>pd",
            "<cmd>FormatDisable<CR>",
            { desc = "Disable auto-format on save" }
        )
        K(
            { "n" },
            "<leader>pe",
            "<cmd>FormatEnable<CR>",
            { desc = "Enable auto-format on save" }
        )
    end,
}
