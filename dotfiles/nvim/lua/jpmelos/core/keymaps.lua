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
K("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" })
K("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" })
K(
    "n",
    "<leader>tf",
    "<cmd>tabnew %<CR>",
    { desc = "Open current buffer in new tab" }
)

-- Navigate line by line in soft-wrapped lines.
K("n", "k", "gk")
K("n", "j", "gj")
