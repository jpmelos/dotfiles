function Input(title, default_value, callback)
    local Input = require("nui.input")
    local event = require("nui.utils.autocmd").event

    local input = Input({
        position = "50%",
        size = { width = 80 },
        border = {
            style = "rounded",
            text = {
                top = " " .. title .. " ",
                top_align = "center",
            },
        },
        win_options = {
            winhighlight = "Normal:Normal,FloatBorder:Normal",
        },
    }, {
        default_value = default_value,
        on_submit = callback,
    })

    input:on(event.BufLeave, function()
        input:unmount()
    end)

    input:map("i", "<C-c>", function()
        input:unmount()
    end, { noremap = true })
    input:map("n", "<C-c>", function()
        input:unmount()
    end, { noremap = true })

    input:mount()
end

function GetVisualSelection()
    if
        vim.fn.mode() == "v"
        or vim.fn.mode() == "V"
        or vim.fn.mode() == "\22"
    then
        return {
            mode = vim.fn.mode(),
            start_pos = vim.fn.getpos("v"),
            end_pos = vim.fn.getpos("."),
        }
    end
    return nil
end

function RestoreVisualSelection(mode, start_pos, end_pos)
    if mode ~= "v" and mode ~= "V" and mode ~= "\22" then
        return
    end

    if mode == "\22" then
        mode = "<C-v>"
    end

    vim.fn.setpos("'<", start_pos)
    vim.fn.setpos("'>", end_pos)
    vim.api.nvim_feedkeys(
        vim.api.nvim_replace_termcodes("`<" .. mode .. "`>", true, false, true),
        "nx",
        false
    )
end

function GetVisualSelectionLines()
    local visual_selection = GetVisualSelection()
    if visual_selection == nil then
        return nil
    end

    local start_line = visual_selection.start_pos[2]
    local end_line = visual_selection.end_pos[2]
    if start_line > end_line then
        start_line, end_line = end_line, start_line
    end

    return { start_line, end_line }
end

function GetGitHubLineFormatForSelection()
    local visual_selection_lines = GetVisualSelectionLines()
    if visual_selection_lines == nil then
        return nil
    end

    local start_line = visual_selection_lines[1]
    local end_line = visual_selection_lines[2]

    if start_line == end_line then
        return "#L" .. start_line
    else
        return "#L" .. start_line .. "-L" .. end_line
    end
end

function GetBufferContents(bufnr, lines)
    if bufnr == nil then
        bufnr = 0
    end

    local start_line, end_line
    if lines == nil then
        start_line = 0
        end_line = -1
    else
        start_line = lines[1]
        end_line = lines[2]
    end

    return table.concat(
        vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false),
        "\n"
    )
end

function NormalMode()
    if vim.fn.mode() == "i" then
        vim.cmd("stopinsert")
        return
    end
    if vim.fn.mode() == "v" then
        vim.cmd("normal! v")
        return
    end
    if vim.fn.mode() == "V" or vim.fn.mode() == "\22" then
        vim.cmd("normal! vv")
        return
    end
end

function RunForOutput(cmd, raw)
    local output = vim.system({ "bash", "-c", cmd }, { text = true }):wait()
    if output.code ~= 0 then
        return nil,
            "Command failed with: " .. (output.stderr or "unknown error")
    end

    local stdout = output.stdout
    local stderr = output.stderr
    if not stdout or stdout == "" then
        if stderr and stderr ~= "" then
            return nil, stderr
        end
        return nil, "No output"
    end

    if raw then
        return stdout, nil
    end
    return stdout:trim(), nil
end

function RemoveEntriesFromQuickfix()
    if vim.fn.mode() ~= "V" and vim.fn.mode() ~= "n" then
        vim.notify(
            "Operation only available in normal mode and visual line modes"
        )
        NormalMode()
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
            NormalMode()
        end
        vim.cmd(del_idx + 1 .. "")
    else
        vim.cmd("cclose")
    end
end

function UpdateGitBranch()
    local git_branch, _ = RunForOutput("git branch | grep '^* '")
    if git_branch == nil then
        vim.g.git_branch = "(error)"
    else
        if git_branch:match("no branch, rebasing") then
            vim.g.git_branch = "(rebasing)"
        else
            vim.g.git_branch = git_branch:sub(3)
        end
    end
    vim.cmd("redrawtabline")
end

function GetGitBranchForStatusLine()
    if vim.g.git_branch == nil then
        return ""
    end
    return " " .. vim.g.git_branch
end

function GetLspServers()
    local clients = ""
    for _, client in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
        clients = clients .. client.config.name .. ","
    end

    if clients == "" then
        return clients
    end

    return "[" .. clients:sub(1, -2) .. "]"
end

function OpenCurrentBufferInNewTab()
    local pos = vim.fn.getpos(".")
    vim.cmd("tabnew %")
    vim.fn.setpos(".", { 0, pos[2], pos[3], 0 })
end

vim.api.nvim_create_user_command("Redir", function(ctx)
    local lines = vim.split(
        vim.api.nvim_exec2(ctx.args, { output = true }).output,
        "\n",
        { plain = true }
    )
    vim.cmd("new")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.opt_local.modified = false
end, { nargs = "+", complete = "command" })

vim.api.nvim_exec2(
    [[
        function! StartsWith(longer, shorter) abort
            return a:longer[0:len(a:shorter)-1] ==# a:shorter
        endfunction

        function! EndsWith(longer, shorter) abort
            return a:longer[len(a:longer)-len(a:shorter):] ==# a:shorter
        endfunction

        function! Contains(longer, shorter) abort
            return stridx(a:longer, a:short) >= 0
        endfunction

        function! IsRecording() abort
            let reg = reg_recording()
            if reg == ""
                return ""
            endif
            return "@" .. reg
        endfunction

        function! GitBranch() abort
            return luaeval("GetGitBranchForStatusLine()")
        endfunction

        function! LspServers() abort
            return luaeval("GetLspServers()")
        endfunction
    ]],
    {}
)
