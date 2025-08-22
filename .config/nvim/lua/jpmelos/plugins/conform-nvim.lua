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
-- ```
-- vim.g.disable_autoformat = { "**/Cargo.lock" }
-- ```
-- Use a repository-local `.nvim.lua` file to configure formatters for specific
-- projects. Like this:
-- ```
-- vim.g.formatters_by_ft = { python = { ... } }
-- ```
-- If all you need is to override some values from the default configuration,
-- do it like this. Changing `vim.g.formatters_by_ft` directly doesn't work as
-- expected:
-- ```
-- local formatters_by_ft = vim.g.formatters_by_ft
-- formatters_by_ft.python = { ... }
-- vim.g.formatters_by_ft = formatters_by_ft
-- ```

local function do_format(conform, range)
    -- Trim trailing whitespaces before formatting.
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    for i, line in ipairs(lines) do
        local trimmed = line:gsub("%s+$", "")
        if trimmed ~= line then
            vim.api.nvim_buf_set_lines(0, i - 1, i, false, { trimmed })
        end
    end

    local cb = function(did_edit)
        -- If didn't format anything, there's nothing to do.
        if not did_edit then
            return
        end

        -- Save the buffer after formatting.
        vim.cmd("write")
    end

    -- When formatting Markdown files, exclude:
    -- - The frontmatter, which is not dealt with very well by `mdformat`, my
    --   current Markdown formatter.
    -- - Any lines that start with `{{`. This mustache notation is used by
    --   Zola, the static site generator that I use, and many other generators,
    --   to interpolate values in Markdown. `mdformat` may break these lines in
    --   ways that will break the interpolation, thus we don't want them to be
    --   changed in any way.
    if vim.bo.filetype == "markdown" then
        lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        if #lines == 0 then
            return
        end

        -- First pass: Exclude frontmatter from the formatting range.
        if range == nil then
            if lines[1] == "---" or lines[1] == "+++" then
                local frontmatter_delimiter = lines[1]
                for i = 2, #lines do
                    if lines[i] == frontmatter_delimiter then
                        range = {
                            start = { i + 1, 0 },
                            ["end"] = { #lines, 99999 },
                        }
                        break
                    end
                end
            end
        end

        -- Second pass: Exclude `{{` interpolation code from the file before
        -- formatting, and put them back in later, to stop `mdformat` from
        -- breaking them.
        local replacements = {}
        local random_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            .. "abcdefghijklmnopqrstuvwxyz"
            .. "0123456789"

        local start_line = 1
        local end_line = #lines
        if range ~= nil then
            start_line = range.start[1]
            end_line = range["end"][1]
        end

        for i = start_line, end_line do
            if lines[i]:match("^{{") then
                local random_id = ""
                for _ = 1, 100 do
                    local random_index = math.random(1, #random_chars)
                    random_id = random_id
                        .. random_chars:sub(random_index, random_index)
                end

                replacements[random_id] = lines[i]

                vim.api.nvim_buf_set_lines(0, i - 1, i, false, { random_id })
            end
        end

        cb = function(did_edit)
            -- If didn't format anything, then just undo the replacements
            -- instead.
            if not did_edit then
                local n_replacements = 0
                for _ in pairs(replacements) do
                    n_replacements = n_replacements + 1
                end

                if n_replacements > 0 then
                    vim.cmd(
                        "let save_cursor = getpos('.')"
                            .. "| undo "
                            .. "| call setpos('.', save_cursor)"
                    )
                end
                return
            end

            local post_format_lines =
                vim.api.nvim_buf_get_lines(0, 0, -1, false)

            for i, line in ipairs(post_format_lines) do
                if replacements[line] then
                    vim.api.nvim_buf_set_lines(
                        0,
                        i - 1,
                        i,
                        false,
                        { replacements[line] }
                    )
                end
            end

            -- Save the buffer after formatting.
            vim.cmd("write")
        end
    end

    local bufnr = vim.api.nvim_get_current_buf()
    conform.format({
        async = true,
        lsp_format = "never",
        range = range,
    }, function(err, did_edit)
        vim.api.nvim_buf_call(bufnr, function()
            cb(did_edit)
        end)
    end)
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
        conform.formatters.rustfmt =
            { options = { default_edition = "2024" } }
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
                        do_format(conform)
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
                                filename:matchglob(pattern)
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
                    do_format(conform)
                end

                if type(g.enable_autoformat) == "string" then
                    g.enable_autoformat = { g.enable_autoformat }
                end

                if type(g.enable_autoformat) == "table" then
                    -- If the filetype or filename of the current buffer is in
                    -- `g.enable_autoformat`, then format it.
                    for _, pattern in ipairs(g.enable_autoformat) do
                        if
                            filename:matchglob(pattern)
                            or vim.bo.filetype == pattern
                        then
                            do_format(conform)
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

        api.nvim_create_user_command("Format", function()
            local range = nil

            local lines = GetVisualSelectionLines()
            if lines ~= nil then
                range = {
                    start = { lines[1], 0 },
                    ["end"] = { lines[2], 99999 },
                }
            end

            do_format(conform, range)

            NormalMode()
        end, { desc = "Format" })

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

        K("n", "<leader>pf", "<cmd>Format<CR>", { desc = "Format file" })
        K("v", "<leader>pf", "<cmd>Format<CR>", { desc = "Format selection" })
        K(
            { "n" },
            "<leader>pe",
            "<cmd>FormatEnable<CR>",
            { desc = "Enable autoformat on save" }
        )
        K(
            { "n" },
            "<leader>pd",
            "<cmd>FormatDisable<CR>",
            { desc = "Disable autoformat on save" }
        )
        K(
            { "n" },
            "<leader>pt",
            "<cmd>FormatToggle<CR>",
            { desc = "Toggle autoformat on save" }
        )
    end,
}
