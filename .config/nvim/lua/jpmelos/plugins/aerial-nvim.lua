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
        open_automatic = true,
        close_on_select = false,
        attach_mode = "global",

        backends = { "treesitter", "markdown", "asciidoc", "man" },

        layout = {
            width = 20,
            default_direction = "left",
            placement = "edge",
            preserve_equality = true,
        },
        show_guides = true,

        -- To see all supported values, use `:h SymbolKind`.
        filter_kind = {
            ["_"] = false,
            python = { "Class", "Function" },
        },

        highlight_mode = "split_width",
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
            vim.keymap.set("n", "{", "<cmd>AerialPrev<cr>", { buffer = bufnr })
            vim.keymap.set("n", "}", "<cmd>AerialNext<cr>", { buffer = bufnr })
        end,
    },
}
