return {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    lazy = false,
    dependencies = {
        "williamboman/mason.nvim",
    },
    config = function()
        require("mason-tool-installer").setup({
            -- Install language servers with `mason-lspconfig.nvim` to
            -- ensure automatic configuration.
            ensure_installed = {},
        })
    end,
}
