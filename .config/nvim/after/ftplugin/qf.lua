local K = vim.keymap.set

K("n", "dd", RemoveEntriesFromQuickfix, { buffer = true })
K("v", "d", function()
    RemoveEntriesFromQuickfix()
end, { buffer = true })
