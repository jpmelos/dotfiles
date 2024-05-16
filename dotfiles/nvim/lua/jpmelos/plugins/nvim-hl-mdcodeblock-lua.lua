return {
    "yaocccc/nvim-hl-mdcodeblock.lua",
    lazy = false,
    dependencies = { "nvim-treesitter" },
    init = function()
        vim.cmd("hi MDCodeBlock gui=none guifg=none guibg=#eeeeee")
    end,
    opts = {
        padding_right = 0,
        minumum_len = 0,
    },
}
