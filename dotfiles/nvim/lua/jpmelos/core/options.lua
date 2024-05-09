-- Set default Neovim's explorer to tree mode.
vim.cmd("let g:netrw_liststyle = 3")

local opt = vim.opt -- For conciseness.

-- Disable mouse entirely.
opt.mouse = ""
-- Keep cursor at the middle of the screen.
opt.scrolloff = 1000

-- Show line numbers.
opt.number = true
-- Show relative numbers for all but the current line.
opt.relativenumber = true
-- Always show sign column so that text doesn't shift.
opt.signcolumn = "yes"

-- 4 spaces for tabs.
opt.tabstop = 4
-- Expand tab to spaces.
opt.expandtab = true
-- Copy indent from current line when starting new one.
opt.autoindent = true
-- 4 spaces for indent width.
opt.shiftwidth = 4

-- Do not wrap lines.
opt.wrap = false
-- Highlight column for text wrapping.
opt.colorcolumn = "80"

-- Ignore case when searching...
opt.ignorecase = true
-- ... unless you have mixed case in your search,
-- then assume case-sensitive.
opt.smartcase = true

-- Highlight current line.
opt.cursorline = true

-- Enable true colors.
opt.termguicolors = true
-- Color schemes that can be light or dark will be light.
opt.background = "light"

-- Allow backspace on indent, end of line or insert mode start position.
opt.backspace = "indent,eol,nostop"

-- Integrate with the system's clipboard.
-- Relies on having an external tool installed for integration.
-- See `:h clipboard-tool` for more.
opt.clipboard:append("unnamedplus")

-- Splitting windows.
opt.splitright = true -- Split vertical windows to the right.
opt.splitbelow = true -- Split horizontal window to the bottom.

-- Turn off swapfiles.
opt.swapfile = false

-- Simple status line.
opt.statusline = "%f %y %m %r%=%c,%l/%L"

-- What to save in sessions.
opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize"
    .. ",winpos,terminal,localoptions"

-- Make jumps behave like browser navigation.
opt.jumpoptions = "stack"
