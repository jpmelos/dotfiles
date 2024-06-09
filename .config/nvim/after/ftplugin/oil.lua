local o = vim.opt
local K = vim.keymap.set
local actions = require("oil.actions")

o.colorcolumn = ""

K("n", "<CR>", actions.select.callback)
K("n", "<ESC>", "<cmd>q<cr>")
