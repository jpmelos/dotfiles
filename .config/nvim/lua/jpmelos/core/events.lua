local au = vim.api.nvim_create_autocmd

-- Prevent ftplugins from re-enabling auto line-breaking. Many built-in
-- ftplugins add 'c' (auto-wrap comments), 't' (auto-wrap text), and 'a'
-- (auto-format paragraphs) back via `setlocal formatoptions+=...`, overriding
-- the global setting in options.lua.
au("FileType", {
    pattern = "*",
    callback = function()
        vim.opt_local.formatoptions:remove({ "c", "t", "a" })
    end,
})

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

-- Open `path/to/file:174` at line 174, just like `path/to/file +174`. Neovim
-- treats the whole argument as a file name, so it lands in `BufNewFile` for a
-- file that does not exist. Replace the buffer with the part before the colon
-- and jump to the line. If that file does not exist either, this opens a new
-- buffer for it, the same as `+174` does.
au("BufNewFile", {
    pattern = "*:[0-9]*",
    -- Let the `:edit` below fire the usual `BufRead`, `FileType`, and related
    -- events for the real file.
    nested = true,
    callback = function(ev)
        local path, line_text = ev.file:match("^(.+):(%d+)$")
        local line = tonumber(line_text)
        if not path or not line then
            return
        end

        local placeholder_buf = ev.buf
        vim.cmd.edit(vim.fn.fnameescape(path))

        -- Defer the rest until every other `BufNewFile` handler for the
        -- placeholder buffer ran, so that none of them sees a deleted
        -- buffer. This also lets plugins that restore the cursor position
        -- on load run first, so that the requested line wins.
        vim.schedule(function()
            if vim.api.nvim_buf_is_valid(placeholder_buf) then
                vim.api.nvim_buf_delete(placeholder_buf, { force = true })
            end

            local line_count = vim.api.nvim_buf_line_count(0)
            local target = math.min(line, line_count)
            vim.api.nvim_win_set_cursor(0, { math.max(target, 1), 0 })
            vim.cmd("normal! zz")
        end)
    end,
})

-- When a file changes on disk (even if the buffer has unsaved changes), always
-- reload from disk, discarding the in-memory edits.
au("FileChangedShell", {
    callback = function()
        vim.v.fcs_choice = "reload"
    end,
})
-- Reload files when coming back to Neovim.
au("FocusGained", { command = "checktime" })
-- Save files automatically when leaving Neovim. Run `checktime` first so that
-- `FileChangedShell` fires for any files changed on disk during this session,
-- reloading them before we write, ensuring disk always wins on conflict.
au("FocusLost", {
    nested = true,
    callback = function()
        vim.cmd("checktime")
        vim.cmd("silent! wa")
    end,
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
        vim.keymap.set("v", "p", SmartPasteLink, {
            buffer = ev.buf,
            desc = "Paste URL as markdown link or default paste",
        })
        vim.keymap.set("v", "<C-S-v>", SmartPasteLink, {
            buffer = ev.buf,
            desc = "Paste URL as markdown link or default paste",
        })
    end,
})
