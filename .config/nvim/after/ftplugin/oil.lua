local K = vim.keymap.set
local actions = require("oil.actions")

K({ "n", "i" }, "<C-c>", "<CMD>q<CR>", { buffer = true })
