local term = require("term")

local m = {}

function m.is_outside_vim(pane)
    return not term.is_process_running(pane, "nvim")
end

return m
