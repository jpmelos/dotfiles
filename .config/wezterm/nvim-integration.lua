local wezterm = require("wezterm")

local m = {}

function m.is_inside_vim(pane)
    local tty = pane:get_tty_name()
    if tty == nil then
        return false
    end

    local success, _, _ = wezterm.run_child_process({
        "sh",
        "-c",
        "ps -o state= -o comm= -t"
            .. wezterm.shell_quote_arg(tty)
            .. " | "
            .. "grep -iqE '^[^TXZ ]+ +(\\S+\\/)?g?(view|l?n?vim?x?)(diff)?$'",
    })

    return success
end

function m.is_outside_vim(pane)
    return not m.is_inside_vim(pane)
end

return m
