return {
    "williamboman/mason-lspconfig.nvim",
    lazy = false,
    dependencies = {
        "williamboman/mason.nvim",
    },
    config = function()
        require("mason-lspconfig").setup({
            ensure_installed = {
                "lua_ls",
                "pyright",
            },
        })
    end,
}
