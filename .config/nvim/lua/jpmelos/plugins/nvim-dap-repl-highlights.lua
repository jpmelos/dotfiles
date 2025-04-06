return {
    "LiadOz/nvim-dap-repl-highlights",
    lazy = true,
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "mfussenegger/nvim-dap",
        "rcarriga/nvim-dap-ui",
    },
    config = function()
        local parsers = require("nvim-treesitter.parsers")
        if not parsers.has_parser("dap_repl") then
            vim.cmd("TSInstall dap_repl")
        end
        require("nvim-dap-repl-highlights").setup()
    end,
}
