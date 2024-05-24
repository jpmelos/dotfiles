return {
    "nvim-tree/nvim-tree.lua",
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
        local K = vim.keymap.set

        -- Recommended settings from documentation.
        vim.g.loaded_netrw = 1
        vim.g.loaded_netrwPlugin = 1

        require("nvim-tree").setup({
            view = {
                width = 35,
                number = true,
                relativenumber = true,
            },
            renderer = {
                indent_markers = {
                    enable = true,
                },
                icons = {
                    glyphs = {
                        folder = {
                            -- Arrow right when folder is closed.
                            arrow_closed = "",
                            -- Arrow when folder is open.
                            arrow_open = "",
                        },
                    },
                },
            },
            -- Disable window picker for explorer to work well with window
            -- splits.
            actions = {
                open_file = {
                    window_picker = {
                        enable = false,
                    },
                },
            },
            git = {
                ignore = false, -- Do not omit files ignored by git.
            },
        })

        K(
            "n",
            "<leader>ee",
            "<cmd>NvimTreeOpen<CR>",
            { desc = "Open/focus file explorer" }
        )
        K(
            "n",
            "<leader>ef",
            "<cmd>NvimTreeFindFile<CR>",
            { desc = "Open/focus file explorer on current file" }
        )
        K(
            "n",
            "<leader>ec",
            "<cmd>NvimTreeCollapse<CR>",
            { desc = "Collapse entries in file explorer" }
        )
        K(
            "n",
            "<leader>er",
            "<cmd>NvimTreeRefresh<CR>",
            { desc = "Refresh file explorer" }
        )
        K(
            "n",
            "<leader>ex",
            "<cmd>NvimTreeClose<CR>",
            { desc = "Close file explorer" }
        )
    end,
}
