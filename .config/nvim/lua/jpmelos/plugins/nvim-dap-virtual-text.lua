return {
    "theHamsta/nvim-dap-virtual-text",
    lazy = false,
    dependencies = {
        "mfussenegger/nvim-dap",
        "nvim-treesitter/nvim-treesitter",
    },
    config = function()
        require("nvim-dap-virtual-text").setup({
            only_first_definition = false,
            all_references = true,
            virt_text_pos = "eol",
        })
    end,
}
