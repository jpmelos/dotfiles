local opt = vim.opt
local opt_local = vim.opt_local
local api = vim.api
local cmd = vim.cmd
local fn = vim.fn

-- Disable swapfiles.
opt.swapfile = false

-- Save undo history.
opt.undofile = true

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
-- 4 spaces for indent width.
opt.shiftwidth = 4
-- Expand tab to spaces.
opt.expandtab = true
-- Copy indent from current line when starting new one.
opt.autoindent = true

-- Soft-wrap lines.
opt.wrap = true
-- No need to worry about where you break the line.
opt.linebreak = false
-- Indent the same way as the parent line, to keep blocks intact.
opt.breakindent = true
-- Shift broken lines by the same number of columns as the tab stop, to make it
-- move obvious it'a broken.
opt.breakindentopt = "shift:4"
-- Show ↪ in front of broken lines.
opt.showbreak = "↪"

-- Set text width for automatic formatting.
opt.textwidth = 79
-- Fine-tune formatting.
-- -t: Automatically format text. Do not enable when working with code.
-- +c: Automatically format comments.
-- +r: Automatically add comment leader upon <Enter> in insert mode.
-- +o: Automatically insert comment leader if using "o" or "O" for new line in a
--     comment in normal mode.
-- +/: Only insert comment leader in next line if comment is the entire line. Do
--     not continue a comment that started after a statement in the preceding
--     line.
-- +q: Allow formatting with `gq`.
-- -w: A trailing white space at the end of a line indicates the paragraph
--     continues in the next line. In other words, it behaves like an empty
--     line normally would.
-- +a: Automatically format paragraphs. If 'c' is used, this only happens for
--     recognized comments.
-- +n: Consider lists, as they are defined in `formatlistpat`. Should not be
--     used with '2'.
-- -2: Always format text according to the indentation of the second line of
--     paragraphs. This is to allow for paragraphs that have different
--     indentation levels at the first line then the rest. Should not be used
--     with 'n'.
-- -v: Vi-compatible line wrapping. This is buggy, do not use.
-- -b: Like 'v', but with a slight difference. Do not use too.
-- -l: Do not format lines that were longer than `textwidth` when Insert-mode
--     started.
-- -m: Break inside multibyte characters. Horrible idea!
-- -M: Related to multibyte characters. Do not use.
-- -B: Related to multibyte characters. Do not use.
-- -1: Don't break lines after 1-letter words, break before it.
-- +]: Respect `textwidth` strictly.
-- +j: Remove comment leader when joining lines.
-- -p: Don't break lines at '.' followed by just one space. This is good for
--     people who put two spaces after periods, which I don't.
opt.formatoptions = "cro/qn]j"
-- Use Vim's default formatter.
opt.formatexpr = ""
-- Use Vim's default formatter.
opt.formatprg = ""

opt.listchars = {
    eol = "$",
    tab = ">-",
    space = "•",
    lead = "•",
    trail = "•",
    extends = "→",
    precedes = "←",
    conceal = " ",
    nbsp = "⇔",
}

-- Don't conceal anything. Projects that want to customize this should use a
-- workspace and a `.nvim.lua` file in their root directory.
opt.conceallevel = 0
-- Conceal in all modes.
opt.concealcursor = ""

-- Disable folding everywhere.
opt.foldenable = false

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

-- Simple statusline and tabline.
opt.statusline = " %f %y %m %r %= %{LspServers()} %l/%L-%v %02p%% "
opt.showtabline = 2
opt.tabline = " [%{tabpagenr()}/%{tabpagenr('$')}] %= %{GitBranch()} "

-- What to save in sessions.
opt.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize"
    .. ",winpos,terminal,localoptions"

-- Make jumps behave like browser navigation.
opt.jumpoptions = "stack"
