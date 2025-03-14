return {
    "nvim-treesitter/nvim-treesitter-refactor",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
        require("nvim-treesitter.configs").setup({
            refactor = {
                highlight_definitions = {
                    enable = true,
                    clear_on_cursor_move = false,
                },
            },
        })
    end,
}
