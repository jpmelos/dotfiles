-- Use "<leader>" when setting keymaps to leverage this constant.
vim.g.mapleader = " "

local K = vim.keymap.set

-- Disable using <ESC> to leave insert mode.
K("i", "jj", "<ESC>", { noremap = true, silent = true })
K({ "i", "v", "c" }, "<ESC>", "<NOP>", { noremap = true, silent = true })

-- Tab management.
K("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" })
K("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" })
K("n", "<leader>tf", function()
    local pos = vim.fn.getpos(".")
    vim.cmd("tabnew %")
    vim.fn.setpos(".", { 0, pos[2], pos[3], 0 })
end, { desc = "Open current buffer in new tab" })

-- Tab navigation.
K("n", "<C-M-h>", "<cmd>tabp<CR>", { desc = "Previous tab" })
K("n", "<C-M-l>", "<cmd>tabn<CR>", { desc = "Next tab" })

-- These mappings control the size of splits (height/width)
K("n", "<M-h>", "<c-W>5>")
K("n", "<M-j>", "<C-W>-")
K("n", "<M-k>", "<C-W>+")
K("n", "<M-l>", "<c-W>5<")

-- Navigate line by line in soft-wrapped lines.
K(
    { "n", "v" },
    "k",
    "v:count == 0 ? 'gk' : 'k'",
    { expr = true, silent = true, desc = "Navigate one screen line up" }
)
K(
    { "n", "v" },
    "j",
    "v:count == 0 ? 'gj' : 'j'",
    { expr = true, silent = true, desc = "Navigate one screen line down" }
)
K("n", "-", "_")

-- Lots of tools, like telescope and others, rely on V to make a vertical
-- split, and X to make a horizontal split. Let's follow that lead here.
K("n", "<C-w>x", "<cmd>split<cr>")
K("n", "<C-w>v", "<cmd>vsplit<cr>")

-- C-u and C-d only jump half screen.
K({ "n", "v" }, "<C-u>", function()
    local half_window = math.ceil(
        vim.api.nvim_win_get_height(vim.api.nvim_get_current_win()) / 2
    ) - 1
    return half_window .. "k"
end, { expr = true, desc = "Jump half screen up" })
K({ "n", "v" }, "<C-d>", function()
    local half_window = math.ceil(
        vim.api.nvim_win_get_height(vim.api.nvim_get_current_win()) / 2
    ) - 1
    return half_window .. "j"
end, { expr = true, desc = "Jump half screen down" })

-- Always search with "very magic" (the \v thing).
K("n", "/", "/\\v", { noremap = true })
K("n", "?", "?\\v", { noremap = true })
K("n", "\\", ":%s/\\v", { noremap = true })

-- Clear search highlights like this, since we use C-l to navigate through
-- splits. See plugin Navigator.nvim.
K(
    { "i", "n" },
    "<C-n>",
    "<cmd>nohls<cr>",
    { desc = "Clear search highlights" }
)

-- Copy path of current buffer to clipboard.
K(
    "n",
    "<leader>by",
    '<cmd>let @+ = expand("%:.")<cr>',
    { desc = "Copy relative path to clipboard" }
)
K(
    "n",
    "<leader>bY",
    '<cmd>let @+ = expand("%:p")<cr>',
    { desc = "Copy absolute path to clipboard" }
)
