-- Returns true if `dir` is a child of `parent`.
local is_dir_in_parent = function(dir, parent)
    if parent == nil then
        return false
    end

    local ws_str_find, _ = string.find(dir, parent, 1, true)
    if ws_str_find == 1 then
        return true
    else
        return false
    end
end

-- Convenience function which wraps `is_dir_in_parent` with active file and
-- workspace.
local current_file_in_ws = function()
    local workspaces = require("workspaces")
    local ws_path = require("workspaces.util").path

    local current_ws = workspaces.path()
    local current_file_dir = ws_path.parent(vim.fn.expand("%:p", true))

    return is_dir_in_parent(current_file_dir, current_ws)
end

-- Function that changes workspace to the one of the active buffer.
local change_workspace_on_buf_change = function()
    -- Do nothing if not a regular buffer.
    local buf_type = vim.api.nvim_get_option_value("buftype", { buf = 0 })
    if buf_type ~= "" and buf_type ~= "acwrite" then
        return
    end

    -- Do nothing if already within the active workspace.
    if current_file_in_ws() then
        return
    end

    local workspaces = require("workspaces")
    local ws_path = require("workspaces.util").path
    local current_file_dir = ws_path.parent(vim.fn.expand("%:p", true))

    -- `filtered_ws` contains workspaces that contain current file.
    local filtered_ws = vim.tbl_filter(function(entry)
        return is_dir_in_parent(current_file_dir, entry.path)
    end, workspaces.get())

    -- Select the workspace which path is the longest match.
    local selected_workspace = nil
    for _, value in pairs(filtered_ws) do
        if not selected_workspace then
            selected_workspace = value
        end
        if string.len(value.path) > string.len(selected_workspace.path) then
            selected_workspace = value
        end
    end

    if selected_workspace then
        workspaces.open(selected_workspace.name)
    end
end

local on_workspace_open = function(name)
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
            auto_open = true,
            hooks = { open = on_workspace_open },
        })

        telescope.load_extension("workspaces")

        local my_ws_grp =
            vim.api.nvim_create_augroup("my_ws_grp", { clear = true })
        vim.api.nvim_create_autocmd({ "VimEnter", "BufEnter" }, {
            callback = change_workspace_on_buf_change,
            group = my_ws_grp,
        })

        K(
            "n",
            "<leader>fw",
            telescope.extensions.workspaces.workspaces,
            { desc = "Find workspaces" }
        )
    end,
}
