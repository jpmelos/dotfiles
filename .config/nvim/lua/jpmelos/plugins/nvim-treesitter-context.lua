return {
    "nvim-treesitter/nvim-treesitter-context",
    lazy = false,
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
        require("treesitter-context").setup({ multiline_threshold = 1 })
    end,
}
