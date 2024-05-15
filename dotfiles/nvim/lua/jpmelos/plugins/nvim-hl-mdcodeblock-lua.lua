return {
    "yaocccc/nvim-hl-mdcodeblock.lua",
    lazy = false,
    dependencies = { "nvim-treesitter" },
    init = function()
        vim.cmd("hi MDCodeBlock guibg=#eaeaea")
    end,
    opts = {
        padding_right = 0,
        minumum_len = 0,
    },
}
