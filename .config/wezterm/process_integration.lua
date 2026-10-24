local term = require("term")

local m = {}

function m.is_outside_vim(pane)
    return not term.any_process_is_running(pane, { "nvim" })
end

function m.is_outside_vim_and_tmux(pane)
    return not term.any_process_is_running(pane, { "nvim", "tmux" })
end

return m
