return {
    "stevearc/conform.nvim",
    config = function()
        local g = vim.g
        local b = vim.b
        local bo = vim.bo
        local api = vim.api
        local K = vim.keymap.set

        local conform = require("conform")

        -- Tools used here should be managed by Mason. See
        -- `mason-tool-installer-nvim.lua`.
        conform.setup({
            -- Use a repository-local `.nvim.lua` file to overwrite this for
            -- specific projects. Something like:
            --
            -- ```
            -- local conform = require("conform")
            -- conform.formatters_by_ft.python = {
            --     "ruff_fix",
            --     "ruff_organize_imports",
            --     "black",
            -- }
            -- ```
            formatters_by_ft = {
                sh = { "shfmt" },
                python = {
                    "ruff_fix",
                    "ruff_organize_imports",
                    "ruff_format",
                },
                lua = { "stylua" },
                -- This is an exception, it's not managed by Mason. Instead,
                -- install the Rust toolchain locally.
                rust = { "rustfmt" },
                sql = { "sql_formatter" },
                css = { "prettier" },
                scss = { "prettier" },
                javascript = { "prettier" },
                typescript = { "prettier" },
                yaml = { "prettier" },
                graphql = { "prettier" },
            },
        })

        -- Customize built-in formatters and add your own.
        conform.formatters.shfmt = {
            prepend_args = {
                "--language-dialect=bash",
                "--indent=4",
                "--binary-next-line",
                "--case-indent",
                "--space-redirects",
            },
        }

        -- ButWritePost: After saving a buffer.
        -- Note: Autoformat is disabled by default, since `g.enable_autoformat`
        -- starts out as `nil`, which resolves to `false` in boolean contexts.
        -- Use a repository-local `.nvim.lua` file to enable it for specific
        -- projects.
        api.nvim_create_autocmd("BufWritePost", {
            callback = function()
                -- Do not autoformat if we're saving because Neovim lost focus.
                if not g.nvim_has_focus then
                    return
                end

                -- Give preference to any buffer-local settings. Since
                -- `b.enable_autoformat` starts out as `nil`, which resolves to
                -- `false` in boolean contexts, this means buffer-local
                -- autosaving is disabled by default.
                if b.enable_autoformat ~= nil then
                    if b.enable_autoformat then
                        -- Save, and then run the formatter. This may leave the
                        -- buffer in an unsaved state again if the formatter
                        -- changes the file.
                        require("conform").format({ async = true })
                    end

                    -- Then it is `false`, which means we don't want to
                    -- autoformat this buffer.
                    return
                end

                if g.enable_autoformat then
                    -- Save, and then run the formatter. This may leave the
                    -- buffer in an unsaved state again if the formatter
                    -- changes the file.
                    require("conform").format({ async = true })
                end

                -- At this point, `g.enable_autoformat` is either `nil` or
                -- `false`, and either way, we don't want to autoformat the
                -- buffer: we only want to autoformat if it is explicitly
                -- enabled.
            end,
        })

        -- Use Vim's internal formatter, instead of `conform.nvim` or an LSP's,
        -- for `gq`. We already don't set this normally, but some LSPs will
        -- change this when they attach to a buffer.
        api.nvim_create_autocmd("LspAttach", {
            callback = function(args)
                bo[args.buf].formatexpr = ""
            end,
        })

        api.nvim_create_user_command("Format", function(args)
            local range = nil
            if args.count ~= -1 then
                local end_line = api.nvim_buf_get_lines(
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

        api.nvim_create_user_command("FormatDisable", function(args)
            if args.bang then
                -- FormatDisable! will disable formatting just for this buffer.
                b.enable_autoformat = false
            else
                g.enable_autoformat = false
            end
        end, {
            desc = "Disable autoformat on save",
            bang = true,
        })
        api.nvim_create_user_command("FormatEnable", function(args)
            if args.bang then
                -- FormatEnable! will enable formatting just for this buffer.
                b.enable_autoformat = true
            else
                g.enable_autoformat = true
            end
        end, {
            desc = "Enable autoformat on save",
            bang = true,
        })
        api.nvim_create_user_command("FormatToggle", function(args)
            if args.bang then
                if b.enable_autoformat then
                    -- FormatToggle! will enable formatting just for this
                    -- buffer.
                    b.enable_autoformat = false
                else
                    b.enable_autoformat = true
                end
            else
                if g.enable_autoformat then
                    -- FormatToggle! will enable formatting just for this
                    -- buffer.
                    g.enable_autoformat = false
                else
                    g.enable_autoformat = true
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
