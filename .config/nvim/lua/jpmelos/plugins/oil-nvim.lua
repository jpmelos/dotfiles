return {
    "stevearc/oil.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = { { "<leader>eo", desc = "Open oil.nvim" } },
    config = function()
        local K = vim.keymap.set

        local oil = require("oil")

        oil.setup({
            default_file_explorer = false,
            columns = { "icon" },
            constrain_cursor = "name",
            use_default_keymaps = false,
            view_options = { show_hidden = true },
            float = { padding = 10 },
            keymaps = {
                ["g?"] = { "actions.show_help", mode = "n" },
                ["<CR>"] = "actions.select",
                ["<C-r>"] = "actions.refresh",
                ["<C-v>"] = { "actions.select", opts = { vertical = true } },
                ["<C-x>"] = { "actions.select", opts = { horizontal = true } },
                ["<C-t>"] = { "actions.select", opts = { tab = true } },
                ["<C-c>"] = { "actions.close", mode = "n" },
                ["-"] = { "actions.parent", mode = "n" },
                ["_"] = { "actions.open_cwd", mode = "n" },
                ["`"] = { "actions.cd", mode = "n" },
                ["~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
                ["gs"] = { "actions.change_sort", mode = "n" },
                ["gx"] = "actions.open_external",
                ["g."] = { "actions.toggle_hidden", mode = "n" },
                ["g\\"] = { "actions.toggle_trash", mode = "n" },
            },
        })

        K("n", "<leader>eo", oil.toggle_float, { desc = "Open oil.nvim" })
    end,
}
