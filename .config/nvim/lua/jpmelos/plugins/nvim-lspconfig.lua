local function fix_pyright_hover_doc(err, result, ctx, config)
    result.contents.value = result.contents.value:gsub("\\_", "_")
    config = vim.tbl_extend("force", config or {}, { border = "rounded" })
    return vim.lsp.handlers.hover(err, result, ctx, config)
end

local original_diagnostic_open_float = vim.diagnostic.open_float
local function show_deduped_diagnostics_in_float(_)
    local seen = {}

    local function dedupe_diagnostic(diag)
        local message = Trim(
            DropFromSubstringToEnd(diag.message, "Suggested replacement:")
        )
        local key = ("%d:%s"):format(diag.lnum, message)
        if not seen[key] then
            seen[key] = true
            return ("[%s] %s"):format(diag.source or "unknown", message)
        end

        return nil
    end

    original_diagnostic_open_float({
        format = dedupe_diagnostic,
        border = "rounded",
    })
end
vim.diagnostic.open_float = show_deduped_diagnostics_in_float

local original_diagnostic_handler_signs_show =
    vim.diagnostic.handlers.signs.show
local function show_deduped_diagnostics_in_signs(
    namespace,
    bufnr,
    diagnostics,
    opts
)
    local seen = {}
    local deduped_diagnostics = {}
    for _, diag in ipairs(diagnostics) do
        local message = Trim(
            DropFromSubstringToEnd(diag.message, "Suggested replacement:")
        )
        local key = ("%d:%s"):format(diag.lnum, message)
        if not seen[key] then
            seen[key] = true
            table.insert(deduped_diagnostics, diag)
        end
    end

    if #deduped_diagnostics > 0 then
        original_diagnostic_handler_signs_show(
            namespace,
            bufnr,
            deduped_diagnostics,
            opts
        )
    end
end
vim.diagnostic.handlers.signs.show = show_deduped_diagnostics_in_signs

return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
        "hrsh7th/cmp-nvim-lsp",
    },
    -- Keep this and the language servers in sync.
    ft = { "sh", "bash", "python", "lua", "rust", "toml", "yaml" },
    config = function()
        local K = vim.keymap.set

        local mason_lspconfig = require("mason-lspconfig")
        local cmp_nvim_lsp = require("cmp_nvim_lsp")

        vim.diagnostic.config({
            severity_sort = true,
            signs = {
                -- Other priority defined for Git signs, being prioritized as
                -- 5.
                priority = 1,
                text = {
                    [vim.diagnostic.severity.ERROR] = " ",
                    [vim.diagnostic.severity.WARN] = " ",
                    [vim.diagnostic.severity.INFO] = " ",
                    [vim.diagnostic.severity.HINT] = "󰠠 ",
                },
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

        local lsp_on_attach = function(client, bufnr)
            vim.cmd("redrawstatus")

            if client.name == "pyright" then
                vim.api.nvim_buf_create_user_command(
                    bufnr,
                    "HoverPyright",
                    function()
                        client.request(
                            "textDocument/hover",
                            vim.lsp.util.make_position_params(0, "utf-8"),
                            fix_pyright_hover_doc
                        )
                    end,
                    { desc = "Show documentation for what is under cursor" }
                )
                vim.api.nvim_buf_set_keymap(
                    bufnr,
                    "n",
                    "K",
                    "<CMD>HoverPyright<CR>",
                    { desc = "Show documentation for what is under cursor" }
                )
            end
        end

        -- Keep the `ft` lazy-loading configuration for this plugin up-to-date,
        -- and the `ensure_installed` list for `mason-lspconfig`.
        vim.lsp.config("pyright", {
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
        vim.lsp.config("lua_ls", {
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
        vim.lsp.config("rust_analyzer", {
            settings = {
                ["rust-analyzer"] = {
                    checkOnSave = false,
                    diagnostics = { enable = false },
                    completion = {
                        fullFunctionSignatures = { enable = true },
                        hideDeprecated = true,
                    },
                },
            },
        })
        vim.lsp.config("*", {
            on_attach = lsp_on_attach,
            capabilities = capabilities,
            root_dir = vim.fn.getcwd(),
        })

        local ensure_installed = {
            -- These are `nvim-lspconfig` names, which will be translated to
            -- Mason package names by `mason-lspconfig.nvim`. Keep this and
            -- `ft` in sync.
            -- bash
            "bashls",
            -- Python
            "pyright",
            -- Lua
            "lua_ls",
            -- Rust
            "rust_analyzer",
            -- TOML
            "taplo",
            -- YAML
            "yamlls",
        }
        mason_lspconfig.setup({
            ensure_installed = ensure_installed,
            automatic_enable = ensure_installed,
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
