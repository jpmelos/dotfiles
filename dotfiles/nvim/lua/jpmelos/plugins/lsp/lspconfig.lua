return {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
        "williamboman/mason.nvim",
        "hrsh7th/cmp-nvim-lsp",
        { "folke/neodev.nvim", opts = {} },
    },
    config = function()
        local lspconfig = require("lspconfig")
        local mason_lspconfig = require("mason-lspconfig")
        local cmp_nvim_lsp = require("cmp_nvim_lsp")

        local keymap = vim.keymap -- For conciseness.

        vim.api.nvim_create_autocmd("LspAttach", {
            group = vim.api.nvim_create_augroup("UserLspConfig", {}),
            callback = function(ev)
                -- Buffer local mappings.
                local opts = { buffer = ev.buf, silent = true }

                opts.desc = "Show LSP references"
                keymap.set(
                    "n",
                    "gr",
                    "<cmd>Telescope lsp_references<CR>",
                    opts
                )

                opts.desc = "Go to declaration"
                keymap.set("n", "gD", vim.lsp.buf.declaration, opts)

                opts.desc = "Show LSP definitions"
                keymap.set(
                    "n",
                    "gd",
                    "<cmd>Telescope lsp_definitions<CR>",
                    opts
                )

                opts.desc = "Show LSP implementations"
                keymap.set(
                    "n",
                    "gi",
                    "<cmd>Telescope lsp_implementations<CR>",
                    opts
                )

                opts.desc = "Show LSP type definitions"
                keymap.set(
                    "n",
                    "gt",
                    "<cmd>Telescope lsp_type_definitions<CR>",
                    opts
                )

                opts.desc = "See available code actions"
                keymap.set(
                    { "n", "v" },
                    "<leader>ca",
                    vim.lsp.buf.code_action,
                    opts
                )

                opts.desc = "Smart rename"
                keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)

                opts.desc = "Show buffer diagnostics"
                keymap.set(
                    "n",
                    "<leader>D",
                    "<cmd>Telescope diagnostics bufnr=0<CR>",
                    opts
                )

                opts.desc = "Show line diagnostics"
                keymap.set("n", "<leader>d", vim.diagnostic.open_float, opts)
                opts.desc = "Go to previous diagnostic"
                keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
                opts.desc = "Go to next diagnostic"
                keymap.set("n", "]d", vim.diagnostic.goto_next, opts)

                opts.desc = "Show documentation for what is under the cursor"
                keymap.set("n", "K", vim.lsp.buf.hover, opts)

                opts.desc = "Restart LSP"
                keymap.set("n", "<leader>rs", ":LspRestart<CR>", opts)
            end,
        })

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
                                globals = { "vim" },
                            },
                        },
                    },
                })
            end,
        })
    end,
}
