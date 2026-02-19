-- Use "<leader>" when setting keymaps to leverage this constant.
vim.g.mapleader = " "

local K = vim.keymap.set

-- Use `jj` to leave insert mode, disable using <ESC>.
K("i", "jj", "<ESC>", { noremap = true })
K({ "i", "v", "c" }, "<ESC>", "<NOP>")

-- Disable leaving insert mode via <C-c>
K("i", "<C-c>", "<NOP>")

-- Paste with `p` when Cmd+v is detected.
-- WezTerm sends Ctrl+Shift+V for Cmd+v to make it detectable in terminal.
K({ "n", "v" }, "<C-S-v>", "p", { desc = "Paste" })
K("i", "<C-S-v>", "<ESC>pa", { desc = "Paste" })

-- Disable toggling case with `u` in Visual mode.
K("v", "u", "<NOP>")

-- Indent while remaining in visual mode.
K("v", "<", "<gv")
K("v", ">", ">gv")

-- Visual mode management.
-- When in visual mode, pressing keys that usually enter visual mode will leave
-- instead of changing the visual mode type.
K("v", "v", function()
    NormalMode()
end, { desc = "Exit visual mode" })
K("v", "V", function()
    NormalMode()
end, { desc = "Exit visual mode" })
K("v", "<C-v>", function()
    NormalMode()
end, { desc = "Exit visual mode" })
K("v", "gv", function()
    NormalMode()
end, { desc = "Exit visual mode" })

-- Tab management.
K("n", "<leader>to", "<cmd>tabnew<CR>", { desc = "Open new tab" })
K("n", "<leader>tc", "<cmd>tabclose<CR>", { desc = "Close current tab" })
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
K("n", "<M-h>", "<c-W><")
K("n", "<M-j>", "<C-W>-")
K("n", "<M-k>", "<C-W>+")
K("n", "<M-l>", "<c-W>>")

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

-- Split management.
K("n", "<leader>sx", "<CMD>split<CR>", { desc = "Split vertically" })
K("n", "<leader>sv", "<CMD>vsplit<CR>", { desc = "Split horizontally" })
K("n", "<leader>se", "<C-w>=", { desc = "Distribute splits equally" })
K("n", "<leader>sc", "<CMD>q<CR>", { desc = "Close split" })

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

-- Make `*` select word under cursor for search, without moving to next match.
K("n", "*", function()
    local word = vim.fn.expand("<cword>")
    if word ~= "" then
        vim.fn.setreg("/", "\\<" .. word .. "\\>")
        vim.opt.hlsearch = true
    end
end, { desc = "Select word under cursor for search" })
-- Disable `#` backward search.
K("n", "#", "<NOP>")

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
end, { desc = "Copy relative path" })
K("n", "<leader>bP", function()
    vim.fn.setreg("+", vim.fn.expand("%:p"))
end, { desc = "Copy absolute path" })
K("v", "<leader>bp", function()
    vim.fn.setreg(
        "+",
        vim.fn.expand("%:.") .. GetGitHubLineFormatForSelection()
    )
end, { desc = "Copy relative path" })
K("v", "<leader>bP", function()
    vim.fn.setreg(
        "+",
        vim.fn.expand("%:p") .. GetGitHubLineFormatForSelection()
    )
end, { desc = "Copy absolute path" })

-- Copy current buffer's contents to clipboard.
K("n", "<leader>br", function()
    vim.fn.setreg("+", GetBufferContents())
    NormalMode()
end, { desc = "Copy raw buffer contents" })
K("n", "<leader>by", function()
    local rel_path = vim.fn.expand("%:.")
    local buffer_content = GetBufferContents()
    local formatted_content = "File @"
        .. rel_path
        .. ":\n\n```\n"
        .. buffer_content
        .. "\n```"

    vim.fn.setreg("+", formatted_content)
    NormalMode()
end, { desc = "Copy buffer contents with file path" })
K("v", "<leader>by", function()
    local rel_path = vim.fn.expand("%:.")

    local lines = GetVisualSelectionLines()
    if lines == nil then
        return
    end
    local start_line = lines[1]
    local end_line = lines[2]

    local selected_content =
        GetBufferContents(0, { start_line - 1, end_line })

    local line_info
    if start_line == end_line then
        line_info = "line " .. start_line
    else
        line_info = "lines " .. start_line .. "-" .. end_line
    end

    local formatted_content = "File @"
        .. rel_path
        .. " ("
        .. line_info
        .. "):\n\n```\n"
        .. selected_content
        .. "\n```"

    vim.fn.setreg("+", formatted_content)
    NormalMode()
end, {
    desc = "Copy selected lines with file path",
})

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
        vim.cmd("botright copen")
    end
end, { desc = "Toggle quickfix" })

-- Disable the command history buffer.
K("n", "q:", "<NOP>")
