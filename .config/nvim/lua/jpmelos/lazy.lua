-- Install lazy.
if not vim.fn.isdirectory(vim.g.lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim",
        "--branch=stable",
        vim.g.lazypath,
    })
end

-- Configure lazy.
require("lazy").setup("jpmelos.plugins", {
    -- Do not check for updates automatically.
    checker = { enabled = false },
    -- Do not auto-detect changes to configuration files.
    change_detection = { enabled = false },
    -- Do not install plugins with luarocks.
    rocks = { enabled = false },
})
