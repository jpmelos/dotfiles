local term = require("term")

local m = {}

function m.is_outside_vim(pane)
    return not term.is_process_running(pane, "nvim")
end

function m.is_in_claude(pane)
    return term.is_process_running(pane, "claude")
end

return m
