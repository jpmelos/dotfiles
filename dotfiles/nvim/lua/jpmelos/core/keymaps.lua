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
K({ "n", "v" }, "k", "gk")
K({ "n", "v" }, "j", "gj")

-- C-u and C-d only jump half screen.
K({ "n", "v" }, "<C-u>", function()
    local half_window = math.ceil(
        vim.api.nvim_win_get_height(vim.api.nvim_get_current_win()) / 2
    ) - 1
    return half_window .. "k"
end, { expr = true })
K({ "n", "v" }, "<C-d>", function()
    local half_window = math.ceil(
        vim.api.nvim_win_get_height(vim.api.nvim_get_current_win()) / 2
    ) - 1
    return half_window .. "j"
end, { expr = true })

-- Enter expands folds, backspace collapses folds.
K("n", "<enter>", "zo")
K("n", "<backspace>", "zc")
