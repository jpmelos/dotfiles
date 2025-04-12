local HEIGHT_RATIO = 0.8
local WIDTH_RATIO = 0.5

return {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "stevearc/dressing.nvim", "nvim-tree/nvim-web-devicons" },
    keys = {
        {
            "<leader>ee",
            "<cmd>NvimTreeOpen " .. vim.fn.getcwd() .. "<CR>",
            mode = "n",
            desc = "Open/focus file explorer",
        },
        {
            "<leader>ef",
            "<cmd>NvimTreeFindFile!<CR>",
            mode = "n",
            desc = "Open/focus file explorer on current file",
        },
        {
            "<leader>ec",
            "<cmd>NvimTreeCollapse<CR>",
            mode = "n",
            desc = "Collapse entries in file explorer",
        },
        {
            "<leader>er",
            "<cmd>NvimTreeRefresh<CR>",
            mode = "n",
            desc = "Refresh file explorer",
        },
        {
            "<leader>ex",
            "<cmd>NvimTreeClose<CR>",
            mode = "n",
            desc = "Close file explorer",
        },
    },
    config = function()
        -- Recommended settings from documentation.
        vim.g.loaded_netrw = 1
        vim.g.loaded_netrwPlugin = 1

        local tree = require("nvim-tree")
        local tree_view = require("nvim-tree.view")

        tree.setup({
            view = {
                number = true,
                relativenumber = true,
                float = {
                    enable = true,
                    open_win_config = function()
                        local screen_w = vim.opt.columns:get()
                        local screen_h = vim.opt.lines:get()

                        local window_w = math.floor(screen_w * WIDTH_RATIO)
                        local window_h = math.floor(screen_h * HEIGHT_RATIO)

                        local top_x = math.floor((screen_w - window_w) / 2)
                        local top_y = math.floor((screen_h - window_h) / 2)

                        return {
                            relative = "editor",

                            col = top_x,
                            width = window_w,

                            row = top_y,
                            height = window_h,
                        }
                    end,
                },
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

        vim.api.nvim_create_autocmd({ "VimResized" }, {
            callback = function()
                if tree_view.is_visible() then
                    tree_view.close()
                    tree.open()
                end
            end,
        })

        vim.api.nvim_exec_autocmds(
            "User",
            { pattern = "JpmelosNvimTreeLoaded" }
        )
    end,
}
