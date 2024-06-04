-- Load local ./.nvim.lua file, if one exists.
local my_ws_grp = vim.api.nvim_create_augroup("my_ws_grp", { clear = true })
vim.api.nvim_create_autocmd({ "VimEnter" }, {
    callback = function()
        local exrc_path = vim.fn.getcwd() .. "/.nvim.lua"
        if vim.secure.read(exrc_path) then
            vim.cmd.source(exrc_path)
            vim.notify("Sourced ./.nvim.lua.")
        end
    end,
    group = my_ws_grp,
})

-- See `:help vim.highlight.on_yank()`.
local highlight_group =
    vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
    callback = function()
        vim.highlight.on_yank({ timeout = 1000 })
    end,
    group = highlight_group,
    pattern = "*",
})
