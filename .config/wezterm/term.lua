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
        "ps -o state= -o comm= -t"
            .. wezterm.shell_quote_arg(tty)
            .. " | grep -E '^[^TXZ]'"
            .. " | awk '{gsub(/^-/, \"\", $2); print $2}'"
            .. " | tr '\n' ' '",
    })

    if not success then
        return {}
    end

    local processes = {}
    for process in stdout:gmatch("%S+") do
        table.insert(processes, process)
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
