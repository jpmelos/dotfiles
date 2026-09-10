vim.g.enable_autoformat = true

-- test
vim.api.nvim_create_autocmd("BufEnter", {
    pattern = ".claude-origin/settings.json",
    callback = function()
        vim.opt_local.shiftwidth = 2
        vim.opt_local.tabstop = 2
    end,
})
