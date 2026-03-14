local wezterm = require("wezterm")

local m = {}

-- Check if a Docker container name belongs to Claude Code.
local function is_claude_code_container(container_name)
    return container_name:match("^claude_code_")
        or container_name:match("^agentcontainer_")
end

-- Resolve the process name when `docker` is the foreground process on the TTY.
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

-- Resolve the tmux pane TTY when `tmux` is active on the given TTY. Uses the
-- WezTerm pane's TTY to find the `tmux` client, then looks up the active
-- `tmux` pane's TTY.
--
-- Returns `(pane_tty, true)` when a `tmux` client is found and the pane TTY
-- can be resolved. Returns `(nil, true)` when a client is found but the pane
-- TTY cannot be determined. Returns `(nil, false)` when no `tmux` client is
-- attached to this TTY.
local function resolve_tmux_pane_tty(tty)
    -- Find the `tmux` session attached to this TTY.
    local success, stdout = wezterm.run_child_process({
        "/opt/homebrew/bin/tmux",
        "list-clients",
        "-F",
        "#{client_tty} #{session_name}",
    })
    if not success or stdout:match("^%s*$") then
        return nil, false
    end

    -- Match the client TTY to our TTY to find the session name.
    local session_name = nil
    for line in stdout:gmatch("[^\n]+") do
        local client_tty, session = line:match("^(%S+)%s+(.+)")
        if client_tty == tty then
            session_name = session
            break
        end
    end
    if session_name == nil then
        return nil, false
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
        return nil, true
    end

    local pane_tty = stdout:match("^%s*(%S+)")
    if pane_tty == nil then
        return nil, true
    end

    return pane_tty, true
end

-- Find the foreground process on a TTY using `ps stat` '+' filtering.
local function find_foreground_process(tty)
    -- Use `stat` (not state) to get the '+' foreground process group
    -- indicator.
    local success, stdout, _ = wezterm.run_child_process({
        "sh",
        "-c",
        "ps -o stat= -o args= -t"
            .. wezterm.shell_quote_arg(tty)
            .. " | awk '$1 ~ /\\+/ {line=$0} END {if (line) print line}'",
    })

    if not success or stdout:match("^%s*$") then
        return nil, nil
    end

    -- Extract the full arguments (everything after the `stat` column).
    local args = stdout:match("^%s*%S+%s+(.+)")
    if args == nil then
        return nil, nil
    end

    local process_path = args:match("^(%S+)")
    if process_path == nil then
        return nil, nil
    end

    -- Strip leading dash (login shell indicator).
    process_path = process_path:gsub("^%-", "")
    -- Strip path prefix (e.g. /usr/bin/docker -> docker).
    local process_name = process_path:match("([^/]+)$")

    return process_name, args
end

local function get_current_process_name(pane)
    local tty = pane:get_tty_name()
    if tty == nil then
        return nil
    end

    -- Check for a `tmux` client on this TTY first. `tmux` calls `setpgid(0,
    -- 0)` at startup, which moves it into its own process group while ignoring
    -- `SIGTTIN`/`SIGTTOU` so it can still use the terminal. This makes it
    -- invisible to the `ps stat` '+' foreground filter, so we detect it by
    -- querying `tmux` directly instead.
    local pane_tty, tmux_found = resolve_tmux_pane_tty(tty)
    if tmux_found and pane_tty == nil then
        -- We are in `tmux` but can't identify the TTY. We can't proceed from
        -- here.
        return "tmux"
    end

    local process_name, args = find_foreground_process(pane_tty or tty)
    if process_name == nil then
        return nil
    end

    -- If the foreground process is `docker`, try to identify what's running
    -- inside the container.
    if process_name == "docker" then
        process_name = resolve_docker_process(args)
    end

    return process_name
end

function m.is_process_running(pane, process_name)
    return get_current_process_name(pane) == process_name
end

return m
