local wezterm = require("wezterm")

local m = {}

-- Check if a Docker container name belongs to Claude Code.
local function is_claude_code_container(container_name)
    return container_name:match("^cc_")
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

    if process_name == "docker" then
        return resolve_docker_process(args)
    end

    return process_name
end

function m.is_process_running(pane, process_name)
    return get_current_process_name(pane) == process_name
end

return m
