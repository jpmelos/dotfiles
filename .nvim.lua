local g = vim.g
local api = vim.api
local ol = vim.opt_local

g.enable_autoformat = true

-- Specific color column setting for Lua files.
api.nvim_create_autocmd("FileType", {
    pattern = "lua",
    callback = function()
        ol.colorcolumn = "80"
    end,
})

g.augment_workspace_folders = { vim.fn.getcwd() }
