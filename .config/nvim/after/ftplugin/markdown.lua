-- 2 spaces for tabs.
vim.opt_local.tabstop = 2
-- 2 spaces for indent width.
vim.opt_local.shiftwidth = 2
-- Shift broken lines by the same number of columns as the tab stop, to make it
-- move obvious it'a broken.
vim.opt_local.breakindentopt = "shift:2"

-- Same as in optionsl.lua, look at that file to see what each of these mean.
vim.opt_local.formatoptions = "cro/qn]j"
