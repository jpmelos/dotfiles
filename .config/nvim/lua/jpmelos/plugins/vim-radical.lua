-- Converts numbers between bases.
return {
    "glts/vim-radical",
    dependencies = { "glts/vim-magnum" },
    keys = {
        { "gA", "<Plug>RadicalView", mode = "n", desc = "Views in bases" },
        {
            "crd",
            "<Plug>RadicalCoerceToDecimal",
            mode = "n",
            desc = "Base to decimal",
        },
        {
            "crb",
            "<Plug>RadicalCoerceToBinary",
            mode = "n",
            desc = "Base to binary",
        },
        {
            "cro",
            "<Plug>RadicalCoerceToOctal",
            mode = "n",
            desc = "Base to octal",
        },
        {
            "crx",
            "<Plug>RadicalCoerceToHex",
            mode = "n",
            desc = "Base to hexadecimal",
        },
    },
    init = function()
        -- Disable default mappings.
        vim.g.radical_no_mappings = true
    end,
}
