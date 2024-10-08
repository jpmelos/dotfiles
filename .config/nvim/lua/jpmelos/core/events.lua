-- Check for focus.
vim.g.nvim_has_focus = true
vim.api.nvim_create_autocmd({ "FocusGained" }, {
    callback = function()
        vim.g.nvim_has_focus = true
    end,
})
vim.api.nvim_create_autocmd({ "FocusLost" }, {
    callback = function()
        vim.g.nvim_has_focus = false
    end,
})

-- Load local ./.nvim.lua file, if one exists.
vim.api.nvim_create_autocmd({ "VimEnter" }, {
    callback = function()
        local exrc_path = vim.fn.getcwd() .. "/.nvim.lua"
        if vim.secure.read(exrc_path) then
            vim.cmd.source(exrc_path)
            vim.notify("Sourced ./.nvim.lua.")
        end
    end,
})

-- See `:help vim.highlight.on_yank()`.
vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function()
        vim.highlight.on_yank({ timeout = 1000 })
    end,
})

-- See `:help vim.highlight.on_yank()`.
vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained" }, {
    callback = UpdateGitBranch,
})
