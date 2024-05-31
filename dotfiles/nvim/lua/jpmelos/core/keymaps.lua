-- Use "<leader>" when setting keymaps to leverage this constant.
vim.g.mapleader = " "

local K = vim.keymap.set

-- Tab management.
K("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" })
K("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" })
K(
    "n",
    "<leader>tf",
    "<cmd>tabnew %<CR>",
    { desc = "Open current buffer in new tab" }
)

-- Tab navigation.
K("n", "[t", "<cmd>tabp<CR>", { desc = "Previous tab" })
K("n", "]t", "<cmd>tabn<CR>", { desc = "Next tab" })

-- Navigate line by line in soft-wrapped lines.
K({ "n", "v" }, "k", "gk", { desc = "Navigate one screen line up" })
K({ "n", "v" }, "j", "gj", { desc = "Navigate one screen line down" })

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

-- Enter expands folds, backspace collapses folds.
K("n", "<enter>", "zo", { desc = "Open fold under cursor" })
K("n", "<backspace>", "zc", { desc = "Close fold under cursor" })

K({ "i", "n" }, "<C-n>", "<cmd>nohls<cr>", { desc = "Clear search highlights" })
