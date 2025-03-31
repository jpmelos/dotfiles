return {
    "uga-rosa/ccc.nvim",
    -- We want to eagerly load this since we use the color highlighter.
    lazy = false,
    keys = {
        {
            "<leader>cp",
            ":CccPick<CR>",
            mode = "n",
            desc = "Open color picker",
        },
        {
            "<leader>cc",
            ":CccConvert<CR>",
            mode = "n",
            desc = "Convert color format",
        },
    },
    opts = {
        preserve = true,
        highlighter = { auto_enable = true },
        recognize = { input = true, output = true },
        mappings = {
            ["$"] = function(core)
                require("ccc").mapping.set100(core)
            end,
        },
    },
}
