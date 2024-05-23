local opt = vim.opt
local opt_local = vim.opt_local
local api = vim.api

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

-- Soft-wrap lines.
opt.wrap = true
-- No need to worry about where you break the line.
opt.linebreak = false
-- Indent the same way as the parent line, to keep blocks intact.
opt.breakindent = true
-- Shift broken lines by two columns, to make it move obvious it'a broken.
opt.breakindentopt = "shift:4"
-- Show ↪ in front of broken lines.
opt.showbreak = "↪"

-- Set text width for automatic formatting.
opt.textwidth = 79
-- Fine-tune formatting.
-- c: Automatically format comments.
-- r: Automatically add comment leader upon <Enter> in insert mode.
-- o: Automatically insert comment leader if using "o" or "O" for new line in a
--    comment in normal mode.
-- /: Only insert comment leader in next line if comment is the entire line. Do
--    not continue a comment that started after a statement in the preceding
--    line.
-- q: Allow formatting with `gq`.
-- n: Consider lists, as they are defined in `formatlistpat`.
-- ]: Respect `textwidth` strictly.
-- j: Remove comment leader when joining lines.
opt.formatoptions = "cro/qn]j"
-- Use Vim's default formatter.
opt.formatexpr = ""
-- Use Vim's default formatter.
opt.formatprg = ""

-- Highlight column for text wrapping.
opt.colorcolumn = "80"
-- Specific colorcolumn setting for git commit files.
api.nvim_create_autocmd("FileType", {
    pattern = "gitcommit",
    callback = function()
        opt_local.colorcolumn = "51,73"
    end,
})

-- Ignore case when searching...
opt.ignorecase = true
-- ... unless you have mixed case in your search, then assume case-sensitive.
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
opt.clipboard = { "unnamedplus" }

-- Splitting windows.
opt.splitright = true -- Split vertical windows to the right.
opt.splitbelow = true -- Split horizontal window to the bottom.

-- Turn off swapfiles.
opt.swapfile = false

-- Make the `CursorHold` event trigger quickly so we can get variable
-- highlights quickly.
opt.updatetime = 200

-- Simple status line.
opt.statusline = " %f %y %m %r %= %v,%l/%L %02p%% "

-- What to save in sessions.
opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize"
    .. ",winpos,terminal,localoptions"

-- Make jumps behave like browser navigation.
opt.jumpoptions = "stack"

-- Reload files on focus.
api.nvim_create_autocmd(
    { "FocusGained", "BufEnter", "BufWinEnter" },
    { command = "checktime" }
)
-- Save files automatically when leaving buffer.
api.nvim_create_autocmd(
    { "FocusLost", "BufLeave", "BufWinLeave" },
    { command = "silent! wa" }
)
