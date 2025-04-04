-- To enable formatting globally:
-- ```
-- vim.g.enable_autoformat = true
-- ```
-- To enable formatting for some filetypes only:
-- ```
-- vim.g.enable_autoformat = { "python", "lua" }
-- ```
-- To disable formatting for some filetypes only:
-- ```
-- vim.g.disable_autoformat = { "sql" }
-- ```
-- `vim.g.enable_autoformat` and `vim.g.disable_autoformat` will also accept
-- glob patterns.
--
-- Use a repository-local `.nvim.lua` file to configure formatters for specific
-- projects. Something like:
-- ```
-- vim.g.formatters_by_ft = { python = { ... } }
-- ```
-- If all you need is to override some values from the default configuration:
-- ```
-- vim.g.formatters_by_ft =
--     require("jpmelos.plugins.conform-nvim").get_default_formatters_by_ft()
-- vim.g.formatters_by_ft.python = { ... }
-- ```
local function get_default_formatters_by_ft()
    return {
        -- BE coding.
        sh = { "shfmt" },
        python = {
            "ruff_fix",
            "ruff_organize_imports",
            "ruff_format",
        },
        lua = { "stylua" },
        -- This is an exception: it's not managed by Mason. Instead,
        -- install the Rust toolchain locally.
        rust = { "rustfmt" },
        -- SQL formatters evaluated so far:
        -- - sql_formatter: Formats ON clauses (in JOINs) wrong, and
        --   aligns AND clauses weirdly.
        -- sql = {},
        -- Web technologies.
        html = { "prettier" },
        css = { "prettier" },
        scss = { "prettier" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        -- Writing.
        markdown = { "mdformat" },
        -- Configuration.
        yaml = { "prettier" },
        toml = { "prettier" },
        json = { "jq" },
        -- Others.
        graphql = { "prettier" },
    }
end
if vim.g.formatters_by_ft == nil then
    vim.g.formatters_by_ft = get_default_formatters_by_ft()
end

return {
    "stevearc/conform.nvim",
    cond = function()
        if #vim.tbl_keys(vim.g.formatters_by_ft) == 0 then
            return false
        end
        return true
    end,
    ft = vim.tbl_keys(vim.g.formatters_by_ft),
    config = function()
        local g = vim.g
        local b = vim.b
        local bo = vim.bo
        local api = vim.api
        local K = vim.keymap.set

        local conform = require("conform")

        -- Tools used here should be managed by Mason. See
        -- `mason-tool-installer-nvim.lua`.
        -- To configure this for a specific project, see
        -- `vim.g.formatters_by_ft` defined above.
        conform.setup({ formatters_by_ft = vim.g.formatters_by_ft })

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
        -- and `b.enable_autoformat` start out as `nil`, which resolves to
        -- `false` in boolean contexts. Use a repository-local `.nvim.lua` file
        -- to enable autoformatting for specific projects, and the commands
        -- `FormatToggle[!]`, `FormatEnable[!]`, and `FormatDisable[!]` to
        -- enable and disable autoformatting globally or for a specific buffer
        -- (with a bang).
        api.nvim_create_autocmd("BufWritePost", {
            callback = function()
                -- Do not autoformat if we're saving because Neovim lost focus.
                if not g.nvim_has_focus then
                    return
                end

                -- Give preference to any buffer-local settings. Since
                -- `b.enable_autoformat` starts out as `nil`, which resolves to
                -- `false` in boolean contexts, this means buffer-local
                -- autoformatting is disabled by default.
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

                -- Filename as a relative path to `vim.fn.getcwd`.
                local filename = vim.fn.fnamemodify(vim.fn.bufname(), ":.")

                if g.disable_autoformat then
                    if type(g.disable_autoformat) == "string" then
                        g.disable_autoformat = { g.disable_autoformat }
                    end

                    -- If the filetype or filename of the current buffer is in
                    -- `g.disable_autoformat`, then do not format it.
                    if type(g.disable_autoformat) == "table" then
                        for _, pattern in ipairs(g.disable_autoformat) do
                            if
                                filename:matchglob(pattern) ~= ""
                                or vim.bo.filetype == pattern
                            then
                                return
                            end
                        end
                    end
                end

                if g.enable_autoformat == true then
                    -- Save, and then run the formatter. This may leave the
                    -- buffer in an unsaved state again if the formatter
                    -- changes the file.
                    require("conform").format({ async = true })
                end

                if type(g.enable_autoformat) == "string" then
                    g.enable_autoformat = { g.enable_autoformat }
                end

                if type(g.enable_autoformat) == "table" then
                    -- If the filetype or filename of the current buffer is in
                    -- `g.enable_autoformat`, then format it.
                    for _, pattern in ipairs(g.enable_autoformat) do
                        if
                            filename:matchglob(pattern) ~= ""
                            or vim.bo.filetype == pattern
                        then
                            require("conform").format({ async = true })
                            break
                        end
                    end
                end

                -- At this point, `g.enable_autoformat` is either `nil` or
                -- `false`, and either way we don't want to autoformat the
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
                range = {
                    start = { args.line1, 0 },
                    ["end"] = { args.line2, math.maxinteger },
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
            { desc = "Toggle autoformat on save" }
        )
        K(
            { "n" },
            "<leader>pd",
            "<cmd>FormatDisable<CR>",
            { desc = "Disable autoformat on save" }
        )
        K(
            { "n" },
            "<leader>pe",
            "<cmd>FormatEnable<CR>",
            { desc = "Enable autoformat on save" }
        )
    end,
    get_default_formatters_by_ft = get_default_formatters_by_ft,
}
