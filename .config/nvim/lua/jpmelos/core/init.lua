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

-- Returns the hash that Neovim's trust database stores for `fullpath`, or
-- `nil` if the file is not in the database. The database format is not public,
-- so this mirrors `read_trust` in Neovim's `runtime/lua/vim/secure.lua`.
local function stored_trust_hash(fullpath)
    local file = io.open(vim.fn.stdpath("state") .. "/trust", "r")
    if not file then
        return nil
    end

    local database = file:read("*a")
    file:close()
    if not database then
        return nil
    end

    for line in vim.gsplit(database, "\n") do
        local hash, path = line:match("^(%S+) (.+)$")
        if hash and path == fullpath then
            return hash
        end
    end

    return nil
end

-- Returns the raw contents of the file at `fullpath`, or `nil` if the file
-- cannot be read.
local function read_file(fullpath)
    local file = io.open(fullpath, "rb")
    if not file then
        return nil
    end

    local content = file:read("*a")
    file:close()
    return content
end

local function source_nvim_lua_file()
    -- Load local ./.nvim.lua file, if one exists.
    local exrc_path = vim.fn.getcwd() .. "/.nvim.lua"
    if vim.fn.filereadable(exrc_path) ~= 1 then
        return
    end

    -- Resolve the path the same way `vim.secure` does, so that the lookup
    -- in the trust database matches.
    local fullpath = vim.uv.fs_realpath(vim.fs.normalize(exrc_path))
    if not fullpath then
        return
    end
    fullpath = vim.fs.normalize(fullpath)

    local current_content = read_file(fullpath)
    if not current_content then
        return
    end

    local content
    if stored_trust_hash(fullpath) ~= vim.fn.sha256(current_content) then
        -- The file is new or changed since it was last trusted. Show it and
        -- ask for approval before trusting it.
        local choice = vim.fn.confirm(
            "exrc: .nvim.lua is new or changed:\n"
                .. fullpath
                .. "\n\n"
                .. current_content
                .. "\nTrust and execute this file?",
            "&Yes\n&No",
            2
        )
        if choice ~= 1 then
            vim.notify("Skipped untrusted .nvim.lua", vim.log.levels.WARN)
            return
        end

        local ok, err =
            vim.secure.trust({ path = fullpath, action = "allow" })
        if not ok then
            vim.notify(
                "Error trusting .nvim.lua: " .. err,
                vim.log.levels.ERROR
            )
            return
        end

        -- Execute exactly the content that the user approved.
        content = current_content
    else
        content = vim.secure.read(fullpath)
        if not content then
            return
        end
    end

    content = content:trim()
    if content ~= "" then
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
