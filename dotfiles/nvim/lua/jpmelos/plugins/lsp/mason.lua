return {
    "williamboman/mason.nvim",
    dependencies = {
        "williamboman/mason-lspconfig.nvim",
        "WhoIsSethDaniel/mason-tool-installer.nvim",
    },
    config = function()
        local mason = require("mason")
        local mason_lspconfig = require("mason-lspconfig")
        -- local mason_tool_installer = require("mason-tool-installer")

        mason.setup({
            ui = {
                icons = {
                    package_installed = "✓",
                    package_pending = "➜",
                    package_uninstalled = "✗",
                },
            },
        })

        mason_lspconfig.setup({
            ensure_installed = {
                "lua_ls",
                "pyright",
            },
        })

        -- We don't want to run these tools from the Vim's PATH, instead we
        -- want to use whatever the current project has in its path. But leave
        -- it here in case we want to install something using Mason in the
        -- future...
        -- mason_tool_installer.setup({
        --     ensure_installed = {
        --         "stylua",
        --         "isort",
        --         "black",
        --     },
        -- })
    end,
}
