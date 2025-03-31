local au = vim.api.nvim_create_autocmd

-- Check for focus.
vim.g.nvim_has_focus = true
au({ "FocusGained" }, {
    callback = function()
        vim.g.nvim_has_focus = true
    end,
})
au({ "FocusLost" }, {
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
au({ "FocusGained" }, { command = "checktime" })
-- Save files automatically when leaving Neovim.
au({ "FocusLost" }, {
    command = "silent! wa",
    nested = true,
})
