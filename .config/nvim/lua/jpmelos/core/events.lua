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
