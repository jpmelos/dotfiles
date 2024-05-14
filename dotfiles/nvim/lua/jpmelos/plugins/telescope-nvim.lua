return {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    lazy = false,
    dependencies = {
        "nvim-lua/plenary.nvim",
        "nvim-telescope/telescope-fzf-native.nvim",
        "nvim-tree/nvim-web-devicons",
        "folke/todo-comments.nvim",
    },
    config = function()
        local K = vim.keymap.set

        local telescope = require("telescope")
        local actions = require("telescope.actions")
        local transform_mod = require("telescope.actions.mt").transform_mod

        local trouble = require("trouble")
        local trouble_telescope = require("trouble.providers.telescope")

        local custom_actions = transform_mod({
            open_trouble_qflist = function(prompt_bufnr)
                trouble.toggle("quickfix")
            end,
        })

        telescope.setup({
            defaults = {
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

        K(
            "n",
            "<leader>ff",
            "<cmd>Telescope find_files<cr>",
            { desc = "Find files in current directory" }
        )
        K(
            "n",
            "<leader>fs",
            "<cmd>Telescope live_grep<cr>",
            { desc = "Find string in current directory" }
        )
        K(
            "n",
            "<leader>fc",
            "<cmd>Telescope grep_string<cr>",
            { desc = "Find string under cursor in current directory" }
        )
        K(
            "n",
            "<leader>ft",
            "<cmd>TodoTelescope<cr>",
            { desc = "Find todos in current directory" }
        )
    end,
}
