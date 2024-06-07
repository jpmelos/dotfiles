local workspace_augroup =
    vim.api.nvim_create_augroup("workspace_augroup", { clear = true })
-- Load local ./.nvim.lua file, if one exists.
vim.api.nvim_create_autocmd({ "VimEnter" }, {
    callback = function()
        local exrc_path = vim.fn.getcwd() .. "/.nvim.lua"
        if vim.secure.read(exrc_path) then
            vim.cmd.source(exrc_path)
            vim.notify("Sourced ./.nvim.lua.")
        end
    end,
    group = workspace_augroup,
})

local yank_highlight_augroup =
    vim.api.nvim_create_augroup("yank_highlight_augroup", { clear = true })
-- See `:help vim.highlight.on_yank()`.
vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function()
        vim.highlight.on_yank({ timeout = 1000 })
    end,
    group = yank_highlight_augroup,
})
