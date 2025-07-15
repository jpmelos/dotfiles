return {
    "nvim-treesitter/nvim-treesitter",
    -- Make sure we always update all parsers when we update tree-sitter.
    build = ":TSUpdate",
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
            -- Better indentation. But for markdown, it's worse... We'll use
            -- `mdformat` with `conform.nvim` instead.
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
                local max_size = 1024 * 1024 -- 1MB
                local size = vim.fn.getfsize(vim.api.nvim_buf_get_name(buf))
                -- size == -2 means the size is so big it doesn't fit in
                -- Neovim's Number type.
                if size > max_size or size == -2 then
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
