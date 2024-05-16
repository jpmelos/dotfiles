-- Use "<leader>" when setting keymaps to leverage this constant.
vim.g.mapleader = " "

local K = vim.keymap.set

-- Window management.
K("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
K("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
K("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
K("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })

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
K("n", "<leader>]t", "<cmd>tabn<CR>", { desc = "Next tab" })
K("n", "<leader>[t", "<cmd>tabp<CR>", { desc = "Previous tab" })

-- Navigate line by line in soft-wrapped lines.
K({ "n", "v" }, "k", "gk")
K({ "n", "v" }, "j", "gj")

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

-- Terminal management.
-- <Esc> leaves the terminal insert mode.
K("t", "<Esc>", "<C-\\><C-n>")
-- Open a terminal split at the bottom of the screen in the current directory.
K("n", "t", function()
    local term_height = math.max(
        math.ceil(
            vim.api.nvim_win_get_height(vim.api.nvim_get_current_win()) / 4
        ) - 1,
        15
    )
    return "<cmd>bo sp term://bash<cr><cmd>resize " .. term_height .. "<cr>i"
end, { expr = true })
