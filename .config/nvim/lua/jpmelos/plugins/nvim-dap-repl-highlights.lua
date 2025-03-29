return {
    "LiadOz/nvim-dap-repl-highlights",
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "mfussenegger/nvim-dap",
        "rcarriga/nvim-dap-ui",
    },
    keys = function(_, opts)
        return require("lazy.core.config").spec.plugins["nvim-dap"].keys
    end,
    config = true,
}
