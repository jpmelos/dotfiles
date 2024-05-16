return {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = {
        "williamboman/mason.nvim",
        "hrsh7th/cmp-nvim-lsp",
        "folke/neodev.nvim",
    },
    config = function()
        local K = vim.keymap.set

        local lspconfig = require("lspconfig")
        local mason_lspconfig = require("mason-lspconfig")
        local cmp_nvim_lsp = require("cmp_nvim_lsp")

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

        -- Capabilities, with the ones added by `nvim-cmp`.
        local capabilities = cmp_nvim_lsp.default_capabilities()

        -- Change the Diagnostic symbols in the sign column.
        local signs =
            { Error = " ", Warn = " ", Hint = "󰠠 ", Info = " " }
        for type, icon in pairs(signs) do
            local hl = "DiagnosticSign" .. type
            vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
        end

        mason_lspconfig.setup_handlers({
            -- Default handler for all servers not explicitly defined here.
            function(server_name)
                lspconfig[server_name].setup({
                    capabilities = capabilities,
                })
            end,
            ["pyright"] = function()
                lspconfig["pyright"].setup({
                    capabilities = capabilities,
                    settings = {
                        python = {
                            -- Only syntax and semantic errors. No type
                            -- checking in the IDE.
                            analysis = {
                                diagnosticMode = "workspace",
                                typeCheckingMode = "off",
                            },
                        },
                    },
                })
            end,
            ["lua_ls"] = function()
                lspconfig["lua_ls"].setup({
                    capabilities = capabilities,
                    settings = {
                        Lua = {
                            -- Make the language server recognize the "vim"
                            -- global. Useful when working with Neovim
                            -- configuration.
                            diagnostics = {
                                disable = { "type-check" },
                                -- TODO: Do we still need globals vim even with
                                -- neodev.nvim?
                                globals = { "vim" },
                            },
                        },
                    },
                })
            end,
        })
    end,
}
