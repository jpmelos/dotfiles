local wezterm = require("wezterm")
local config = wezterm.config_builder()

local appearance = require("appearance")
local keys = require("keys")
local mouse = require("mouse")

appearance.apply_to_config(config)
keys.apply_to_config(config)

config.automatically_reload_config = false

config.audible_bell = "Disabled"

config.check_for_updates = false

-- When opening Wezterm when it's already open, open a new tab in the
-- already-existent instance instead of creating a new one.
config.prefer_to_spawn_tabs = true

config.show_new_tab_button_in_tab_bar = false

return config
