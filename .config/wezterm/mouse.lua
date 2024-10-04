local wezterm = require("wezterm")
local action = wezterm.action
local module = {}

function module.apply_to_config(config)
    config.disable_default_mouse_bindings = true

    config.mouse_bindings = {
        {
            event = { Up = { streak = 1, button = "Left" } },
            mods = "SUPER",
            action = wezterm.action.OpenLinkAtMouseCursor,
        },
    }
end

return module
