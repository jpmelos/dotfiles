local K = vim.keymap.set
local actions = require("oil.actions")

K("n", "<CR>", actions.select.callback, { buffer = true })
K("n", "q", "<CMD>q<CR>", { buffer = true })
