-- Set directory that will hold lazy-related stuff.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
-- Install lazy.
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim",
        "--branch=stable",
        lazypath,
    })
end
-- Add lazy's path to Vim's `PATH`.
vim.opt.rtp:prepend(lazypath)

-- Configure lazy.
require("lazy").setup("jpmelos.plugins", {
    checker = {
        enabled = false, -- Do not check for updates automatically.
    },
    change_detection = {
        enabled = false, -- Do not auto-detect changes to configuration files.
    },
})
