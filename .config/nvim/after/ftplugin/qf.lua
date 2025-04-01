local K = vim.keymap.set

local function remove_entry_from_quickfix()
    if vim.fn.mode() ~= "V" and vim.fn.mode() ~= "n" then
        vim.notify(
            "Operation only available in normal mode and visual line modes"
        )
        return
    end

    local qf_title = vim.fn.getqflist({ title = 0 })
    local qf_entries = vim.fn.getqflist()

    local del_idx, del_count
    if vim.fn.mode() == "V" then
        local line_start = vim.fn.getpos("v")[2]
        local line_end = vim.fn.getpos(".")[2]
        if line_start > line_end then
            line_start, line_end = line_end, line_start
        end

        del_idx = line_start - 1
        del_count = line_end - line_start + 1
    else
        del_idx = vim.fn.getpos(".")[2] - 1
        del_count = 1
    end

    for _ = 1, del_count do
        table.remove(qf_entries, del_idx + 1)
    end
    vim.fn.setqflist(qf_entries, "r")
    vim.fn.setqflist({}, "r", { title = qf_title.title })

    if #qf_entries > 0 then
        if vim.fn.mode() == "V" then
            vim.cmd("normal! V")
        end
        vim.cmd(del_idx + 1 .. "")
    else
        vim.cmd("cclose")
    end
end

K("n", "dd", remove_entry_from_quickfix, { buffer = true })
K("v", "d", function()
    remove_entry_from_quickfix()
end, { buffer = true })
