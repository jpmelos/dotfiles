local au = vim.api.nvim_create_autocmd

-- Check for focus.
vim.g.nvim_has_focus = true
au("FocusGained", {
    callback = function()
        vim.g.nvim_has_focus = true
    end,
})
au("FocusLost", {
    callback = function()
        vim.g.nvim_has_focus = false
    end,
})

au("TextYankPost", {
    callback = function()
        vim.highlight.on_yank({ timeout = 1000 })
    end,
})

au({ "VimEnter", "FocusGained" }, {
    callback = UpdateGitBranch,
})

-- Reload files when coming back to Neovim.
au("FocusGained", { command = "checktime" })
-- Save files automatically when leaving Neovim.
au("FocusLost", {
    command = "silent! wa",
    nested = true,
})

au("QuitPre", {
    callback = function()
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
            local name = vim.api.nvim_buf_get_name(buf)
            if name == "" then
                vim.api.nvim_buf_delete(buf, { force = true })
            end
        end
    end,
})

-- Automatically create links when pasting URLs in visual mode in Markdown
-- files.
au("FileType", {
    pattern = "markdown",
    callback = function(ev)
        vim.keymap.set("v", "p", function()
            -- Get content from clipboard, trim whitespace.
            local content = vim.fn.getreg("+"):match("^%s*(.-)%s*$")

            -- If not a URL, fall back to default paste.
            if not content:match("^https?://") then
                vim.cmd("normal! p")
                return
            end

            -- Get visual selection info before exiting visual mode.
            local start_pos = vim.fn.getpos("v")
            local end_pos = vim.fn.getpos(".")

            -- Get the selected text.
            local start_line = start_pos[2]
            local start_col = start_pos[3]
            local end_line = end_pos[2]
            local end_col = end_pos[3]

            -- Ensure start is before end.
            if
                start_line > end_line
                or (start_line == end_line and start_col > end_col)
            then
                start_line, end_line = end_line, start_line
                start_col, end_col = end_col, start_col
            end

            -- Get selected text.
            local lines = vim.api.nvim_buf_get_text(
                0,
                start_line - 1,
                start_col - 1,
                end_line - 1,
                end_col,
                {}
            )

            -- Join multi-line selections with spaces (Markdown links cannot
            -- span multiple lines).
            local selected_text = table.concat(lines, " ")

            -- Exit visual mode.
            NormalMode()

            -- Format as markdown link (single line).
            local link = string.format("[%s](%s)", selected_text, content)

            -- Check if we are past the end of the line by one column in visual
            -- mode.
            local line_content = vim.api.nvim_buf_get_lines(
                0,
                end_line - 1,
                end_line,
                false
            )[1]
            local final_end_col = end_col
            if end_col > #line_content then
                final_end_col = end_col - 1
            end

            -- Replace selection with link.
            vim.api.nvim_buf_set_text(
                0,
                start_line - 1,
                start_col - 1,
                end_line - 1,
                final_end_col,
                { link }
            )
        end, {
            buffer = ev.buf,
            desc = "Paste URL as markdown link or default paste",
        })
    end,
})
