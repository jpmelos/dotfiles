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

    input:map("n", "q", function()
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
        return { vim.fn.mode(), vim.fn.getpos("v"), vim.fn.getpos(".") }
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

function GetBufferContents(bufnr)
    if bufnr == nil then
        bufnr = 0
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    return table.concat(lines, "\n"):match("^%s*(.-)%s*$")
end

function NormalMode()
    local esc = vim.api.nvim_replace_termcodes("<esc>", true, false, true)
    vim.api.nvim_feedkeys(esc, "x", false)
end

function string.startswith(str, start)
    return str.sub(str, 1, str.len(start)) == start
end

function os.capture(cmd, raw)
    local f = assert(io.popen(cmd, "r"))
    local s = assert(f:read("*a"))
    f:close()

    if raw then
        return s
    end

    s = string.gsub(s, "^%s+", "")
    s = string.gsub(s, "%s+$", "")
    return s
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
    local dot_git_path = vim.fn.getcwd() .. "/.git"
    local in_git_root = vim.fn.isdirectory(dot_git_path) == 1

    if not in_git_root then
        vim.g.git_branch = "not in git root"
    else
        local git_branch = os.capture("git branch | grep '^* '")
        if git_branch:find("no branch, rebasing") then
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
