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
            -- Better indentation.
            indent = {
                enable = true,
                disable = {
                    -- Indentation for bullet points is worse.
                    "markdown",
                },
            },
            -- Enable autotagging with the `nvim-ts-autotag` plugin.
            autotag = { enable = true },
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
                "css",
                "csv",
                "dap_repl",
                "diff",
                "git_config",
                "git_rebase",
                "gitattributes",
                "gitcommit",
                "gitignore",
                "gpg",
                "graphql",
                "html",
                "htmldjango",
                "javascript",
                "json",
                "latex",
                "liquid",
                "make",
                "markdown",
                "markdown_inline",
                "mermaid",
                "passwd",
                -- TODO: "pip_requirements",
                "python",
                "regex",
                "rust",
                "scss",
                "sql",
                "ssh_config",
                "tmux",
                "toml",
                "tsv",
                "tsx",
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
        })

        local opt = vim.opt

        opt.foldmethod = "expr"
        opt.foldexpr = "nvim_treesitter#foldexpr()"
        opt.foldenable = false
    end,
}
