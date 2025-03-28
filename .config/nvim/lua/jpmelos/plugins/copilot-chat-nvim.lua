-- This plugin is enabled only if the environment variable
-- `GH_COPILOT_ENABLED` is set at the time Neovim starts. We don't want to
-- unexpectedly share proprietary code with them.
--
-- The workspace is set to the current working directory by default. To
-- configure a different workspace (for example, because you want to add code
-- that is outside of the current working directory), set this in the project's
-- `.nvim.lua` file (make sure to include `vim.fn.getcwd()` explicitly if you
-- what that to be included):
-- ```
-- vim.g.copilot_workspace_folders = { vim.fn.getcwd(), "/Users/..." }
-- ```
return {
    "CopilotC-Nvim/CopilotChat.nvim",
    cond = function()
        return false
        -- return os.getenv("GH_COPILOT_ENABLED") == "1"
    end,
    dependencies = { "github/copilot.vim", "nvim-lua/plenary.nvim" },
    config = function()
        local g = vim.g
        local api = vim.api
        local ol = vim.opt_local
        local K = vim.keymap.set

        local chat = require("CopilotChat")

        -- Disable GitHub Copilot suggestions.
        g.copilot_filetypes = { ["*"] = false }
        g.copilot_no_tab_map = true

        g.copilot_workspace_folders = { vim.fn.getcwd() }

        chat.setup({
            model = "claude-3.5-sonnet",
            window = { width = 0.4 },
            references_display = "write",
        })

        api.nvim_create_autocmd("FileType", {
            pattern = "copilot-chat",
            callback = function()
                ol.number = false
                ol.relativenumber = false
                ol.conceallevel = 0
            end,
        })

        K(
            { "n", "v" },
            "<leader>aa",
            chat.toggle,
            { desc = "GH Copilot chat" }
        )
        K(
            { "n", "v" },
            "<leader>as",
            chat.reset,
            { desc = "GH Copilot chat reset" }
        )
        K(
            { "n", "v" },
            "<leader>am",
            chat.select_model,
            { desc = "GH Copilot models" }
        )
        K(
            { "n", "v" },
            "<leader>ag",
            chat.select_agent,
            { desc = "GH Copilot agents" }
        )
        K(
            { "n", "v" },
            "<leader>ap",
            chat.select_prompt,
            { desc = "GH Copilot prompts" }
        )
    end,
}
