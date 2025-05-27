return {
    "nvim-telescope/telescope.nvim",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope-ui-select.nvim",
        "nvim-tree/nvim-web-devicons",
        "folke/todo-comments.nvim",
        "nvim-tree/nvim-tree.lua",
        -- This is needed for performance improvements in how Telescope sorts
        -- entries.
        { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
    },
    config = function()
        local api = vim.api
        local K = vim.keymap.set
        local os_sep = require("plenary.path").path.sep

        local telescope = require("telescope")
        local builtins = require("telescope.builtin")
        local actions = require("telescope.actions")
        local themes = require("telescope.themes")

        local tree_api = require("nvim-tree.api")

        local mappings = {
            ["<C-k>"] = actions.move_selection_previous,
            ["<C-j>"] = actions.move_selection_next,
            ["<C-q>"] = actions.smart_send_to_qflist + actions.open_qflist,
            ["<C-o>"] = actions.cycle_history_prev,
            ["<C-p>"] = actions.cycle_history_next,
            ["<C-d>"] = actions.preview_scrolling_down,
            ["<C-f>"] = actions.preview_scrolling_up,
            ["<C-x>"] = actions.file_split,
            ["<C-v>"] = actions.file_vsplit,
            ["<C-t>"] = actions.file_tab,
            ["<C-c>"] = actions.close,
        }
        -- ripgrep arguments come from `$RIPGREP_CONFIG_PATH`. By default, it
        -- is `~/.ripgreprc`, but it may be overridden for projects with
        -- `.autoenv.enter`.
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

                extensions = { ["ui-select"] = { themes.get_dropdown({}) } },

                mappings = { n = mappings, i = mappings },
            },
        })
        telescope.load_extension("fzf")
        telescope.load_extension("ui-select")

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
            if vim.bo.filetype ~= "NvimTree" then
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

        vim.api.nvim_exec_autocmds(
            "User",
            { pattern = "JpmelosTelescopeLoaded" }
        )
    end,
}
