local on_workspace_open = function(name, path)
    local exrc_path = path .. ".nvim.lua"

    local secure_exrc = vim.secure.read(exrc_path)
    if secure_exrc then
        vim.cmd.source(path .. ".nvim.lua")
    else
        vim.notify("Could not load file " .. exrc_path, "error")
    end

    vim.notify("Workspace activated: " .. name .. ".")
end

return {
    "natecraddock/workspaces.nvim",
    lazy = false,
    dependencies = { "nvim-telescope/telescope.nvim" },
    config = function()
        local K = vim.keymap.set

        local workspaces = require("workspaces")
        local telescope = require("telescope")

        workspaces.setup({
            -- Automatically activate a workspace when opening Neovim in a
            -- workspace directory. Does not change workspace when opening a
            -- file from another workspace.
            auto_open = true,
            hooks = { open = on_workspace_open },
        })

        telescope.load_extension("workspaces")

        K(
            "n",
            "<leader>fw",
            telescope.extensions.workspaces.workspaces,
            { desc = "Find workspaces" }
        )
    end,
}
