-- Properly configure LuaLS for editing Neovim configuration by lazily updating
-- your workspace libraries.
return {
    "folke/lazydev.nvim",
    ft = "lua",
    dependencies = { "Bilal2453/luvit-meta" },
}
