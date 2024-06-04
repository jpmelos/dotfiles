-- Set directory that will hold lazy-related stuff.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
-- Install lazy.
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
    })
end
-- Add lazy's path to Vim's `PATH`.
vim.opt.rtp:prepend(lazypath)

-- Configure lazy.
require("lazy").setup("jpmelos.plugins", {
    checker = {
        enabled = true, -- Check for updates automatically.
        notify = false, -- But no need to notify.
    },
    change_detection = {
        notify = false, -- Do not notify about changed lazy files.
    },
})
