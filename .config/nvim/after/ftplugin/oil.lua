local K = vim.keymap.set
local actions = require("oil.actions")

K("n", "<CR>", actions.select.callback, { buffer = true })
K("n", "<ESC>", "<cmd>q<cr>", { buffer = true })
