local wezterm = require("wezterm")

local m = {}

-- Check if a Docker container name belongs to Claude Code.
local function is_claude_code_container(container_name)
    return container_name:match("^claude_code_")
        or container_name:match("^agentcontainer_")
end

-- Resolve the process name when docker is the foreground process on the TTY.
local function resolve_docker_process(args_line)
    local docker_subcommand = args_line:match("docker%s+(%S+)")

    if docker_subcommand ~= "run" then
        return "docker"
    end

    local container_name = args_line:match("%-%-name%s+(%S+)")
        or args_line:match("%-%-name=(%S+)")

    if container_name == nil then
        return "docker"
    end

    if is_claude_code_container(container_name) then
        return "claude"
    end

    return "docker"
end

-- Resolve the process name when tmux is the foreground process on the TTY.
-- Uses the WezTerm pane's TTY to find the tmux client, then looks up the
-- foreground process on the active tmux pane's TTY.
local function resolve_tmux_process(tty)
    -- Find the tmux session attached from this TTY.
    local success, stdout = wezterm.run_child_process({
        "/opt/homebrew/bin/tmux",
        "list-clients",
        "-F",
        "#{client_tty} #{session_name}",
    })

    if not success or stdout:match("^%s*$") then
        return "tmux"
    end

    -- Match the client connected from our TTY to find the session name.
    local session_name = nil
    for line in stdout:gmatch("[^\n]+") do
        local client_tty, session = line:match("^(%S+)%s+(.+)")
        if client_tty == tty then
            session_name = session
            break
        end
    end

    if session_name == nil then
        return "tmux"
    end

    -- Get the active pane's TTY in this session.
    success, stdout, _ = wezterm.run_child_process({
        "/opt/homebrew/bin/tmux",
        "display-message",
        "-t",
        session_name,
        "-p",
        "#{pane_tty}",
    })

    if not success or stdout:match("^%s*$") then
        return "tmux"
    end

    local pane_tty = stdout:match("^%s*(%S+)")
    if pane_tty == nil then
        return "tmux"
    end

    -- Find the foreground process on the tmux pane's TTY.
    success, stdout, _ = wezterm.run_child_process({
        "sh",
        "-c",
        "ps -o stat= -o args= -t"
            .. wezterm.shell_quote_arg(pane_tty)
            .. " | awk '$1 ~ /\\+/ {line=$0} END {if (line) print line}'",
    })

    if not success or stdout:match("^%s*$") then
        return "tmux"
    end

    local args = stdout:match("^%s*%S+%s+(.+)")
    if args == nil then
        return "tmux"
    end

    local process_path = args:match("^(%S+)")
    if process_path == nil then
        return "tmux"
    end

    -- Strip leading dash (login shell indicator).
    process_path = process_path:gsub("^%-", "")
    -- Strip path prefix.
    local process_name = process_path:match("([^/]+)$")

    return process_name, args
end

local function get_current_process_name(pane)
    local tty = pane:get_tty_name()
    if tty == nil then
        return nil
    end

    -- Find the foreground process on the host TTY.
    -- Use stat (not state) to get the '+' foreground process group indicator.
    local success, stdout, _ = wezterm.run_child_process({
        "sh",
        "-c",
        "ps -o stat= -o args= -t"
            .. wezterm.shell_quote_arg(tty)
            .. " | awk '$1 ~ /\\+/ {line=$0} END {if (line) print line}'",
    })

    if not success or stdout:match("^%s*$") then
        return nil
    end

    -- Extract the full args (everything after the stat column).
    local args = stdout:match("^%s*%S+%s+(.+)")
    if args == nil then
        return nil
    end

    local process_path = args:match("^(%S+)")
    if process_path == nil then
        return nil
    end

    -- Strip leading dash (login shell indicator).
    process_path = process_path:gsub("^%-", "")
    -- Strip path prefix (e.g. /usr/bin/docker -> docker).
    local process_name = process_path:match("([^/]+)$")

    -- Dig through docker and tmux layers. If a resolver returns its own
    -- process name, it means it couldn't dig deeper.
    while process_name == "docker" or process_name == "tmux" do
        if process_name == "docker" then
            local resolved = resolve_docker_process(args)
            if resolved == "docker" then
                return "docker"
            end
            process_name = resolved
        elseif process_name == "tmux" then
            local resolved, resolved_args = resolve_tmux_process(tty)
            if resolved == "tmux" then
                return "tmux"
            end
            process_name = resolved
            args = resolved_args
        end
    end

    return process_name
end

function m.is_process_running(pane, process_name)
    return get_current_process_name(pane) == process_name
end

return m
