vim.g.git_branch = nil

function PrintTable(o)
    if type(o) == "table" then
        local s = "{ "
        for k, v in pairs(o) do
            if type(k) ~= "number" then
                k = '"' .. k .. '"'
            end
            s = s .. "[" .. k .. "] = " .. PrintTable(v) .. ","
        end
        return s .. "} "
    else
        return tostring(o)
    end
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

function UpdateGitBranch()
    local dot_git_path = vim.loop.cwd() .. "/.git"
    local in_git_root, _ = vim.loop.fs_stat(dot_git_path)

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
