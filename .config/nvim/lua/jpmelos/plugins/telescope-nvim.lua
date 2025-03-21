return {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope-fzf-native.nvim",
        "nvim-tree/nvim-web-devicons",
        "folke/trouble.nvim",
        "folke/todo-comments.nvim",
        "nvim-tree/nvim-tree.lua",
    },
    config = function()
        local api = vim.api
        local K = vim.keymap.set
        local os_sep = require("plenary.path").path.sep

        local telescope = require("telescope")
        local builtins = require("telescope.builtin")
        local actions = require("telescope.actions")

        local trouble_telescope = require("trouble.sources.telescope")

        local tree_api = require("nvim-tree.api")

        local open_in_trouble_focus = function(telescope_bufnr)
            trouble_telescope.open(telescope_bufnr, { focus = true })
        end

        -- ripgrep arguments come from ~/.ripgreprc.
        telescope.setup({
            defaults = {
                pickers = {
                    -- The command for live_grep and grep_string is specified
                    -- just below.
                    find_files = {
                        find_command = { "rg", "--files", "--color=never" },
                    },
                },
                -- Used for live_grep and grep_string. The command for
                -- find_files is specified just above.
                vimgrep_arguments = { "rg", "--color=never" },

                path_display = { "smart" },
                previewer = { timeout = 1000 },

                history = {
                    path = vim.fn.stdpath("data")
                        .. os_sep
                        .. "telescope_history.sqlite3",
                    limit = 10000,
                },
                cache_picker = {
                    num_pickers = -1,
                    limit_entries = 10000,
                    ignore_empty_prompt = true,
                },

                mappings = {
                    n = {
                        ["<C-k>"] = actions.move_selection_previous,
                        ["<C-j>"] = actions.move_selection_next,
                        ["<C-q>"] = open_in_trouble_focus,
                        ["<C-o>"] = actions.cycle_history_prev,
                        ["<C-p>"] = actions.cycle_history_next,
                        ["<C-d>"] = actions.preview_scrolling_down,
                        ["<C-f>"] = actions.preview_scrolling_up,
                        ["<C-x>"] = actions.file_split,
                        ["<C-v>"] = actions.file_vsplit,
                        ["<C-c>"] = actions.close,
                    },
                    i = {
                        ["<C-k>"] = actions.move_selection_previous,
                        ["<C-j>"] = actions.move_selection_next,
                        ["<C-q>"] = open_in_trouble_focus,
                        ["<C-o>"] = actions.cycle_history_prev,
                        ["<C-p>"] = actions.cycle_history_next,
                        ["<C-d>"] = actions.preview_scrolling_down,
                        ["<C-f>"] = actions.preview_scrolling_up,
                        ["<C-x>"] = actions.file_split,
                        ["<C-v>"] = actions.file_vsplit,
                        ["<C-c>"] = actions.close,
                    },
                },
            },
        })
        telescope.load_extension("fzf")

        --
        -- Files.
        --
        K(
            "n",
            "<leader>ff",
            builtins.find_files,
            { desc = "Find files in current directory" }
        )
        K("n", "<leader>fb", builtins.buffers, { desc = "Find buffers" })
        K("n", "<leader>fo", builtins.oldfiles, { desc = "Find old files" })

        --
        -- Strings.
        --
        K(
            "n",
            "<leader>fa",
            builtins.live_grep,
            { desc = "Find in current directory" }
        )
        K(
            "n",
            "<leader>fca",
            builtins.grep_string,
            { desc = "Find in current directory" }
        )
        K("n", "<leader>fp", function()
            local ft = api.nvim_get_option_value("filetype", {})
            if ft ~= "NvimTree" then
                vim.notify("This command only works in NvimTree.")
                return
            end

            local node = tree_api.tree.get_node_under_cursor()
            if node.type ~= "directory" then
                vim.notify("This command only works on directories.")
                return
            end

            builtins.live_grep({ search_dirs = { node.absolute_path } })
        end, { desc = "Find string in current path" })

        --
        -- Vim.
        --
        K(
            "n",
            "<leader>fh",
            builtins.help_tags,
            { desc = "Find Neovim help tags" }
        )
        K("n", "<leader>fm", builtins.commands, { desc = "Find commands" })
        K(
            "n",
            "<leader>fu",
            builtins.command_history,
            { desc = "Find old commands" }
        )
        K(
            "n",
            "<leader>fi",
            builtins.search_history,
            { desc = "Find old searches" }
        )
        K(
            "n",
            "<leader>fe",
            builtins.highlights,
            { desc = "Find color highlight classes" }
        )

        --
        -- Git.
        --
        K(
            "n",
            "<leader>fg",
            builtins.git_status,
            { desc = "Find git modified files" }
        )
        K(
            "n",
            "<leader>fr",
            builtins.git_bcommits,
            { desc = "Find changes on this file" }
        )
    end,
}
