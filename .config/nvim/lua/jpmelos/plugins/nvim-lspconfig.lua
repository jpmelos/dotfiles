return {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = {
        "williamboman/mason-lspconfig.nvim",
        "hrsh7th/cmp-nvim-lsp",
        "folke/neodev.nvim",
    },
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
            ensure_installed = {
                "bashls",
                "lua_ls",
                "pyright",
                "rust_analyzer",
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
            -- When adding a server here, at a minimum you need to send it
            -- the capabilities table. See below for examples.
            bashls = function()
                lspconfig.bashls.setup({
                    on_attach = lsp_on_attach,
                    capabilities = capabilities,
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
            pyright = function()
                lspconfig.pyright.setup({
                    on_attach = lsp_on_attach,
                    capabilities = capabilities,
                    settings = {
                        pyright = { disableOrganizeImports = true },
                        python = {
                            analysis = {
                                -- Inspect the entire workspace: all importable
                                -- code.
                                diagnosticMode = "workspace",
                                -- Only syntax and semantic errors. No type
                                -- checking in the IDE.
                                typeCheckingMode = "off",
                                -- Do not mess with my path.
                                autoSearchPaths = false,
                            },
                        },
                    },
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
        K(
            "n",
            "K",
            vim.lsp.buf.hover,
            { desc = "Show documentation for what is under cursor" }
        )

        K(
            { "n", "v" },
            "<leader>ca",
            vim.lsp.buf.code_action,
            { desc = "Show LSP code actions" }
        )
        K("n", "<leader>cr", vim.lsp.buf.rename, { desc = "Smart rename" })

        K(
            "n",
            "<leader>ld",
            vim.diagnostic.open_float,
            { desc = "Show line diagnostic" }
        )
        K(
            "n",
            "[d",
            vim.diagnostic.goto_prev,
            { desc = "Previous diagnostic" }
        )
        K("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })
    end,
}
