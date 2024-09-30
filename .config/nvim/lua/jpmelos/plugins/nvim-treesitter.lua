return {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    -- Make sure we always update all parsers when we update tree-sitter.
    build = ":TSUpdate",
    dependencies = {
        -- Automatically open and close HTML tags.
        "windwp/nvim-ts-autotag",
        -- Enable highlighting in the DAP REPL.
        "LiadOz/nvim-dap-repl-highlights",
    },
    config = function()
        require("nvim-treesitter.configs").setup({
            -- Better syntax highlighting.
            highlight = { enable = true },
            -- Incremental selection via tree-sitter with C-Space and
            -- backspace.
            incremental_selection = {
                enable = true,
                keymaps = {
                    init_selection = "<C-space>",
                    node_incremental = "<C-space>",
                    scope_incremental = false,
                    node_decremental = "<bs>",
                },
            },
            -- Better indentation. But for markdown, it's worse...
            indent = { enable = true, disable = { "markdown" } },
            -- Ensure these language parsers are installed.
            ensure_installed = {
                -- These five parsers should always be installed according to
                -- the documentation. :shrug:
                "c",
                "lua",
                "query",
                "vim",
                "vimdoc",
                -- These are optional.
                "bash",
                "cmake",
                "cpp",
                "css",
                "csv",
                "dap_repl",
                "diff",
                "dockerfile",
                "editorconfig",
                "git_config",
                "git_rebase",
                "gitattributes",
                "gitcommit",
                "gitignore",
                "go",
                "gpg",
                "graphql",
                "helm",
                "html",
                "htmldjango",
                "http",
                "javascript",
                "json",
                "latex",
                "liquid",
                "make",
                "markdown",
                "markdown_inline",
                "mermaid",
                "passwd",
                "python",
                "regex",
                "requirements",
                "rust",
                "scss",
                "sql",
                "ssh_config",
                "terraform",
                "tmux",
                "toml",
                "tsv",
                "tsx",
                "typescript",
                "typescript",
                "vue",
                "yaml",
            },
            -- Disable tree-sitter syntax highlighting for large files.
            disable = function(lang, buf)
                local max_filesize = 1024 * 1024 -- 1MB
                local ok, stats =
                    pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
                if ok and stats and stats.size > max_filesize then
                    return true
                end
                return false
            end,
            textobjects = {
                select = {
                    enable = true,
                    lookahead = true,
                    keymaps = {
                        -- You can use the capture groups defined in
                        -- textobjects.scm.
                        ["aa"] = "@parameter.outer",
                        ["ia"] = "@parameter.inner",
                        ["af"] = "@function.outer",
                        ["if"] = "@function.inner",
                        ["ac"] = "@class.outer",
                        ["ic"] = "@class.inner",
                        ["ii"] = "@conditional.inner",
                        ["ai"] = "@conditional.outer",
                        ["il"] = "@loop.inner",
                        ["al"] = "@loop.outer",
                        ["at"] = "@comment.outer",
                    },
                },
            },
        })
    end,
}
