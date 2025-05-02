return {
    "stevearc/aerial.nvim",
    lazy = false,
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "nvim-tree/nvim-web-devicons",
    },
    keys = {
        {
            "<leader>ln",
            "<cmd>AerialOpen<cr>",
            mode = "n",
            desc = "Go to code navigation",
        },
    },
    opts = {
        backends = { "treesitter", "markdown", "asciidoc", "man" },

        layout = {
            default_direction = "float",
            min_width = 0.2,
            max_width = 0.9,
            resize_to_content = "false",
        },
        float = {
            border = "rounded",
            relative = "editor",
            min_height = 0.5,
            max_height = 0.9,
        },

        open_automatic = false,
        close_on_select = true,
        close_automatic_events = { "unfocus", "switch_buffer" },

        attach_mode = "window",
        show_guides = true,

        -- To see all supported values, use `:h SymbolKind`.
        filter_kind = {
            ["_"] = false,
            python = { "Class", "Function" },
        },

        highlight_mode = "last",
        highlight_closest = true,
        highlight_on_hover = true,

        autojump = false,
        highlight_on_jump = 300,

        ignore = {
            unlisted_buffers = true,
            diff_windows = true,
            filetypes = {},
        },

        manage_folds = false,
        -- When you folding in code buffers, update the Aerial buffer as well.
        link_folds_to_tree = false,
        -- When you folding in the Aerial buffer, update code buffers as well.
        link_tree_to_folds = true,

        on_attach = function(bufnr)
            vim.keymap.set(
                "n",
                "<leader>es",
                "<cmd>AerialToggle<cr>",
                { buffer = bufnr, desc = "Toggle symbol nav" }
            )
        end,
    },
}
