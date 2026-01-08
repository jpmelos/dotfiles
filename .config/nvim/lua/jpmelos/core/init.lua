math.randomseed()

require("jpmelos.core.options")
require("jpmelos.core.globals")
require("jpmelos.core.globs")
require("jpmelos.core.strings")
require("jpmelos.core.functions")
require("jpmelos.core.debug")
require("jpmelos.core.events")
require("jpmelos.core.keymaps")
require("jpmelos.core.diagnostics")

-- Add lazy's path to Vim's `PATH`. This will allow things like
-- `require("jpmelos.plugins.conform-nvim")` to be used from `.nvim.lua`
-- project files.
vim.g.lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
vim.opt.rtp:prepend(vim.g.lazypath)

local function source_nvim_lua_file()
    -- Load local ./.nvim.lua file, if one exists.
    local exrc_path = vim.fn.getcwd() .. "/.nvim.lua"
    if vim.fn.filereadable(exrc_path) ~= 1 then
        return
    end

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
            vim.notify(
                "Error loading .nvim.lua: " .. err,
                vim.log.levels.ERROR
            )
        end
    end
end
source_nvim_lua_file()

-- Register custom filetypes from `.nvim.lua` if defined.
if vim.g.custom_filetypes then
    local project_root = vim.fn.getcwd()
    vim.filetype.add({
        pattern = {
            [".*"] = function(path, bufnr)
                -- Check if the file is within the project directory.
                if not path:startswith(project_root) then
                    return nil
                end

                -- Get the path relative to the project root.
                -- +2 to skip the leading and trailing slashes.
                local relative_path = path:sub(#project_root + 2)

                -- Match against each pattern in `vim.g.custom_filetypes`.
                for _, entry in ipairs(vim.g.custom_filetypes) do
                    local pattern, filetype = entry[1], entry[2]
                    if string.matchglob(relative_path, pattern) then
                        return filetype
                    end
                end

                return nil
            end,
        },
    })
end
