require("jpmelos.core.options")
require("jpmelos.core.globals")
require("jpmelos.core.globs")
require("jpmelos.core.strings")
require("jpmelos.core.functions")
require("jpmelos.core.events")
require("jpmelos.core.keymaps")

-- Add lazy's path to Vim's `PATH`. This will allow things like
-- `require("jpmelos.plugins.conform-nvim")` to be used from `.nvim.lua`
-- project files.
vim.g.lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
vim.opt.rtp:prepend(vim.g.lazypath)

-- Load local ./.nvim.lua file, if one exists.
local exrc_path = vim.fn.getcwd() .. "/.nvim.lua"
local content = vim.secure.read(exrc_path):trim()
if content and content ~= "" then
    local chunk, err = load(content, "@" .. exrc_path, "t")
    if chunk then
        local ok, exec_err = pcall(chunk)
        if ok then
            vim.notify("Sourced .nvim.lua")
        else
            vim.notify(
                "Error executing .nvim.lua: " .. exec_err,
                vim.log.levels.ERROR
            )
        end
    else
        vim.notify("Error loading .nvim.lua: " .. err, vim.log.levels.ERROR)
    end
end
