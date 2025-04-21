-- Use "<leader>" when setting keymaps to leverage this constant.
vim.g.mapleader = " "

local K = vim.keymap.set

-- Disable using <ESC> to leave insert mode.
K("i", "jj", function()
    local current_column = vim.fn.getpos(".")[3]
    if current_column == 0 then
        return "<ESC>"
    else
        return "<ESC>l"
    end
end, { noremap = true, expr = true })
K({ "i", "v", "c" }, "<ESC>", "<NOP>")

-- Disable leaving insert mode via <C-c>
K("i", "<C-c>", "<NOP>")

-- Disable toggling case with `u` in Visual mode.
K("v", "u", "<NOP>")

-- Indent while remaining in visual mode.
K("v", "<", "<gv")
K("v", ">", ">gv")

-- Tab management.
K("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" })
K("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" })
K(
    "n",
    "<leader>tf",
    OpenCurrentBufferInNewTab,
    { desc = "Open current buffer in new tab" }
)

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
    { expr = true, desc = "Navigate one screen line up" }
)
K(
    { "n", "v" },
    "j",
    "v:count == 0 ? 'gj' : 'j'",
    { expr = true, desc = "Navigate one screen line down" }
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

-- Make `n` always search forward and `N` always search backward, no matter
-- what was the original direction of the search operation.
K("n", "n", function()
    return vim.v.searchforward == 1 and "n" or "N"
end, { expr = true })
K("n", "N", function()
    return vim.v.searchforward == 1 and "N" or "n"
end, { expr = true })

-- Clear search highlights like this, since we use C-l to navigate through
-- splits. See plugin Navigator.nvim.
K(
    { "i", "n" },
    "<C-n>",
    "<cmd>nohls<cr>",
    { desc = "Clear search highlights" }
)

-- Copy path of current buffer to clipboard. If in Visual Mode, put the
-- selected lines at the end of the path too, in GitHub format.
K("n", "<leader>bp", function()
    vim.fn.setreg("+", vim.fn.expand("%:."))
end, { desc = "Copy relative path to clipboard" })
K("n", "<leader>bP", function()
    vim.fn.setreg("+", vim.fn.expand("%:p"))
end, { desc = "Copy absolute path to clipboard" })
K("v", "<leader>bp", function()
    vim.fn.setreg(
        "+",
        vim.fn.expand("%:.") .. GetGitHubLineFormatForSelection()
    )
end, { desc = "Copy relative path with line numbers to clipboard" })
K("v", "<leader>bP", function()
    vim.fn.setreg(
        "+",
        vim.fn.expand("%:p") .. GetGitHubLineFormatForSelection()
    )
end, { desc = "Copy absolute path with line numbers to clipboard" })

-- Quickfix list
K("n", "<leader>qq", function()
    local qf_exists = false
    for _, win in pairs(vim.fn.getwininfo()) do
        if win.quickfix == 1 then
            qf_exists = true
            break
        end
    end

    if qf_exists then
        vim.cmd("cclose")
    else
        vim.cmd("copen")
    end
end, { desc = "Toggle quickfix" })

-- Disable the command history buffer.
K("n", "q:", "<NOP>")
