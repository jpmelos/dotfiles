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
        })

        K("n", "<leader>eo", oil.toggle_float, { desc = "Open oil.nvim" })
    end,
}
