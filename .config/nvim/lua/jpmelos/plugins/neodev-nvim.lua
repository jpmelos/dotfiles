return {
    "folke/neodev.nvim",
    lazy = false,
    dependencies = { "rcarriga/nvim-dap-ui" },
    opts = {
        library = { plugins = { "nvim-dap-ui" }, types = true },
    },
}
