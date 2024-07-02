local ol = vim.opt_local

-- 2 spaces for tabs.
ol.tabstop = 2
-- 2 spaces for indent width.
ol.shiftwidth = 2
-- Shift broken lines by the same number of columns as the tab stop, to make it
-- move obvious it'a broken.
ol.breakindentopt = "shift:2"
