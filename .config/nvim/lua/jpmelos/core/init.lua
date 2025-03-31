require("jpmelos.core.functions")
require("jpmelos.core.events")
require("jpmelos.core.options")
require("jpmelos.core.keymaps")

-- Load local ./.nvim.lua file, if one exists.
local exrc_path = vim.fn.getcwd() .. "/.nvim.lua"
if vim.secure.read(exrc_path) then
    vim.cmd.source(exrc_path)
    vim.notify("Sourced ./.nvim.lua.")
end
