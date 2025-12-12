local workspaces =
    { { name = "second-brain", path = "~/devel/second-brain" } }

return {
    "obsidian-nvim/obsidian.nvim",
    version = "*",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "hrsh7th/nvim-cmp",
        "nvim-telescope/telescope.nvim",
        "nvim-treesitter/nvim-treesitter",
        "iamcco/markdown-preview.nvim",
    },
    -- Only load when we are in one of the defined workspaces.
    cond = function()
        local cwd = vim.fn.getcwd()

        for _, workspace in ipairs(workspaces) do
            local expanded_path = vim.fn.expand(workspace.path)
            if cwd == expanded_path then
                return true
            end
        end

        return false
    end,
    config = function()
        local K = vim.keymap.set

        require("obsidian").setup({
            legacy_commands = false,
            ui = { enable = false },
            statusline = { enabled = false },
            footer = { enabled = false },

            workspaces = workspaces,

            completion = {
                nvim_cmp = true,
                min_chars = 1,
            },

            templates = {
                folder = "00-templates",
                date_format = "%Y-%m-%d",
                time_format = "%H:%M",
                -- A map for custom variables, the key should be the
                -- variable and the value a function
                substitutions = {},
            },
            daily_notes = {
                folder = "02-dailies",
                date_format = "%Y-%m-%d",
                alias_format = "%Y-%m-%d",
                template = "daily-note.md",
            },

            note_id_func = function(title)
                if title ~= nil then
                    return title
                        :gsub(" ", "-")
                        :gsub("[^A-Za-z0-9-_]", "_")
                        :lower()
                end

                local note_id = ""
                for _ = 1, 16 do
                    note_id = note_id .. string.char(math.random(97, 122))
                end
                return note_id
            end,

            follow_url_func = function(url)
                if vim.fn.system("uname -s"):trim() == "Darwin" then
                    -- MacOS
                    vim.fn.jobstart({ "open", url })
                else
                    -- Linux
                    vim.notify(
                        "Fix this, make it specific for Linux in"
                            .. "obsidian.nvim."
                    )
                    vim.fn.jobstart({ "xdg-open", url }) -- linux
                end
            end,

            picker = {
                name = "telescope.nvim",
                mappings = { insert_link = "<C-l>" },
            },

            checkbox = {
                enabled = true,
                create_new = true,
                order = { " ", "x" },
            },
        })

        vim.api.nvim_create_autocmd("User", {
            pattern = "ObsidianNoteEnter",
            command = "MarkdownPreview",
        })

        K(
            "n",
            "<leader>on",
            "<cmd>Obsidian new<cr>",
            { desc = "Open new note" }
        )
        K(
            "n",
            "<leader>ot",
            "<cmd>Obsidian new_from_template<cr>",
            { desc = "Open new note from template" }
        )
        K(
            "n",
            "<leader>od",
            "<cmd>Obsidian today<cr>",
            { desc = "Open today's daily note" }
        )
    end,
}
