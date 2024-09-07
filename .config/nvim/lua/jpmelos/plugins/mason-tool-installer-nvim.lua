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
            -- shellcheck: Not explicitly referenced in these dotfiles, but
            -- it's used by `bashls` to provide some of its functionalities.
            ensure_installed = { "shellcheck", "shfmt", "ruff", "stylua" },
        })
    end,
}
