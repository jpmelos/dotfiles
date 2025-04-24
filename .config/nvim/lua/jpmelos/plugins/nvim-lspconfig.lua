return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "hrsh7th/cmp-nvim-lsp",
    },
    -- Keep this and the language servers in sync.
    ft = { "bash", "python", "lua", "rust", "sql", "toml", "yaml" },
    config = function()
        local K = vim.keymap.set

        local lspconfig = require("lspconfig")
        local mason_lspconfig = require("mason-lspconfig")
        local cmp_nvim_lsp = require("cmp_nvim_lsp")

        -- Change the Diagnostic symbols in the sign column.
        local signs =
            { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
        for type, icon in pairs(signs) do
            local hl = "DiagnosticSign" .. type
            vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
        end

        mason_lspconfig.setup({
            -- These are `nvim-lspconfig` names, which will be translated to
            -- Mason package names by `mason-lspconfig.nvim`.
            -- Keep this and `ft` in sync.
            ensure_installed = {
                -- bash
                "bashls",
                -- Python
                "pyright",
                -- Lua
                "lua_ls",
                -- Rust
                "rust_analyzer",
                -- SQL
                "sqlls",
                -- TOML
                "taplo",
                -- YAML
                "yamlls",
            },
        })

        -- Capabilities, with the ones added by `nvim-cmp`.
        local capabilities = vim.tbl_deep_extend(
            "force",
            -- Default Neovim capabilities.
            vim.lsp.protocol.make_client_capabilities(),
            -- Add nvim-cmp capabilities.
            cmp_nvim_lsp.default_capabilities()
        )

        local lsp_on_attach = function()
            vim.cmd("redrawstatus")
        end

        mason_lspconfig.setup_handlers({
            -- When adding a server here, at a minimum you need to send it the
            -- capabilities table and set the `on_attach` handler. See below
            -- for examples. Also keep the `ft` lazy-loading configuration for
            -- this plugin up-to-date.
            bashls = function()
                lspconfig.bashls.setup({
                    on_attach = lsp_on_attach,
                    capabilities = capabilities,
                })
            end,
            pyright = function()
                lspconfig.pyright.setup({
                    on_attach = lsp_on_attach,
                    capabilities = capabilities,
                    settings = {
                        pyright = { disableOrganizeImports = true },
                        python = {
                            analysis = {
                                autoImportCompletions = true,
                                diagnosticMode = "openFilesOnly",
                                typeCheckingMode = "off",
                                useLibraryCodeForTypes = false,
                                autoSearchPaths = false,
                            },
                        },
                    },
                })
            end,
            lua_ls = function()
                lspconfig.lua_ls.setup({
                    on_attach = lsp_on_attach,
                    capabilities = capabilities,
                    settings = {
                        Lua = {
                            diagnostics = {
                                disable = { "type-check" },
                                -- Make the language server recognize the "vim"
                                -- global. Useful when working with Neovim
                                -- configuration.
                                globals = { "vim" },
                            },
                        },
                    },
                })
            end,
            rust_analyzer = function()
                lspconfig.rust_analyzer.setup({
                    on_attach = lsp_on_attach,
                    capabilities = capabilities,
                    settings = {
                        ["rust-analyzer"] = {
                            completion = {
                                fullFunctionSignatures = {
                                    enable = true,
                                },
                                hideDeprecated = true,
                            },
                            diagnostics = {
                                styleLints = {
                                    enable = true,
                                },
                            },
                        },
                    },
                })
            end,
            sqlls = function()
                lspconfig.sqlls.setup({
                    on_attach = lsp_on_attach,
                    capabilities = capabilities,
                })
            end,
            taplo = function()
                lspconfig.taplo.setup({
                    on_attach = lsp_on_attach,
                    capabilities = capabilities,
                })
            end,
            yamlls = function()
                lspconfig.yamlls.setup({
                    on_attach = lsp_on_attach,
                    capabilities = capabilities,
                })
            end,
        })

        K(
            "n",
            "gr",
            "<cmd>Telescope lsp_references<CR>",
            { desc = "Show LSP references" }
        )
        K(
            "n",
            "gd",
            "<cmd>Telescope lsp_definitions<CR>",
            { desc = "Show LSP definitions" }
        )
        K(
            "n",
            "gt",
            "<cmd>Telescope lsp_type_definitions<CR>",
            { desc = "Show LSP type definitions" }
        )
        K(
            "n",
            "gi",
            "<cmd>Telescope lsp_implementations<CR>",
            { desc = "Show LSP implementations" }
        )
        K(
            "n",
            "gs",
            "<cmd>Telescope lsp_document_symbols<CR>",
            { desc = "Show LSP symbols in buffer" }
        )
        K(
            "n",
            "gS",
            "<cmd>Telescope lsp_workspace_symbols<CR>",
            { desc = "Show LSP symbols in workspace" }
        )
        K("n", "K", function()
            vim.lsp.buf.hover({
                border = "rounded",
            })
        end, { desc = "Show documentation for what is under cursor" })

        K(
            { "n", "v" },
            "<leader>ca",
            vim.lsp.buf.code_action,
            { desc = "Show LSP code actions" }
        )
        K("n", "<leader>cr", vim.lsp.buf.rename, { desc = "Smart rename" })

        K("n", "<leader>lr", "<cmd>LspRestart<CR>", { desc = "Restart LSPs" })
        K("n", "<leader>ld", function()
            vim.diagnostic.open_float({ border = "rounded" })
        end, { desc = "Show line diagnostic" })
        K("n", "[d", function()
            vim.diagnostic.goto_prev({ float = { border = "rounded" } })
        end, { desc = "Previous diagnostic" })
        K("n", "]d", function()
            vim.diagnostic.goto_next({ float = { border = "rounded" } })
        end, { desc = "Next diagnostic" })
    end,
}
