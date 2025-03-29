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
    config = function()
        local parsers = require("nvim-treesitter.parsers")
        if not parsers.has_parser("dap_repl") then
            vim.cmd("TSInstall dap_repl")
        end
        require("nvim-dap-repl-highlights").setup()
    end,
}
