local o = vim.opt
local K = vim.keymap.set

o.colorcolumn = ""

K("n", "<ESC>", "<cmd>q<cr>", { buffer = true })
