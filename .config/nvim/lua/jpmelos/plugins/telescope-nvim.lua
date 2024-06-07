local get_parent = function(path)
    return path:match("(.*" .. "/" .. ")")
end

return {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    lazy = false,
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope-fzf-native.nvim",
        "nvim-tree/nvim-web-devicons",
        "folke/todo-comments.nvim",
        "nvim-tree/nvim-tree.lua",
    },
    config = function()
        local api = vim.api
        local K = vim.keymap.set

        local telescope = require("telescope")
        local builtins = require("telescope.builtin")
        local actions = require("telescope.actions")
        local transform_mod = require("telescope.actions.mt").transform_mod

        local trouble = require("trouble")
        local trouble_telescope = require("trouble.providers.telescope")

        local tree_api = require("nvim-tree.api")

        local custom_actions = transform_mod({
            open_trouble_qflist = function()
                trouble.toggle("quickfix")
            end,
        })

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
                mappings = {
                    n = {
                        ["<C-k>"] = actions.move_selection_previous,
                        ["<C-j>"] = actions.move_selection_next,
                        ["<C-q>"] = actions.send_selected_to_qflist
                            + custom_actions.open_trouble_qflist,
                        ["<C-t>"] = trouble_telescope.smart_open_with_trouble,
                    },
                    i = {
                        ["<C-k>"] = actions.move_selection_previous,
                        ["<C-j>"] = actions.move_selection_next,
                        ["<C-q>"] = actions.send_selected_to_qflist
                            + custom_actions.open_trouble_qflist,
                        ["<C-t>"] = trouble_telescope.smart_open_with_trouble,
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
            "<leader>fs",
            builtins.live_grep,
            { desc = "Find string in current directory" }
        )
        K(
            "n",
            "<leader>fc",
            builtins.grep_string,
            { desc = "Find string under cursor in current directory" }
        )
        K("n", "<leader>fp", function()
            local ft = api.nvim_get_option_value("filetype", {})
            local path

            if ft == "NvimTree" then
                local node = tree_api.tree.get_node_under_cursor()
                path = node.absolute_path
                if node.type ~= "directory" then
                    path = get_parent(path)
                end
            else
                path = api.nvim_buf_get_name(0)
                path = get_parent(path)
            end

            builtins.live_grep({ search_dirs = { path } })
        end, { desc = "Find string in current path" })

        --
        -- Todos.
        --
        K(
            "n",
            "<leader>ft",
            telescope.extensions["todo-comments"].todo,
            { desc = "Find todos in current directory" }
        )

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
            { desc = "Find old searches" }
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
