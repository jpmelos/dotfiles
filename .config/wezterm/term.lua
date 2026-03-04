local wezterm = require("wezterm")

local m = {}

function m.get_current_process_name(pane)
    local tty = pane:get_tty_name()
    if tty == nil then
        return {}
    end

    local success, stdout, _ = wezterm.run_child_process({
        "sh",
        "-c",
        "ps -o state= -o args= -t"
            .. wezterm.shell_quote_arg(tty)
            .. " | grep -E '^[^TXZ]'"
            .. " | awk '{gsub(/^-/, \"\", $2); print}'",
    })

    if not success then
        return {}
    end

    local processes = {}
    for line in stdout:gmatch("[^\n]+") do
        -- Extract the process name (first arg after the state column).
        local process_name = line:match("^%S+%s+(%S+)")
        if process_name then
            -- Strip any leading path (e.g. /usr/bin/docker -> docker).
            process_name = process_name:match("([^/]+)$")
            table.insert(processes, process_name)

            -- If this is a Docker command running a Claude Code container
            -- (named with a `cc_` prefix), also report "claude".
            if process_name == "docker" then
                local container_name = line:match("%-%-name%s+(%S+)")
                if container_name and container_name:match("^cc_") then
                    table.insert(processes, "claude")
                end
            end
        end
    end

    return processes
end

function m.is_process_running(pane, process_name)
    local processes = m.get_current_process_name(pane)
    for _, process in ipairs(processes) do
        if process == process_name then
            return true
        end
    end
    return false
end

return m
