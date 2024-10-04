local module = {}

function module.apply_to_config(config)
    local foreground_color = "#474747"
    local background_color = "#fafafa"

    local padding_px = 5

    config.window_decorations = "RESIZE"
    config.use_fancy_tab_bar = false
    config.tab_bar_at_bottom = true

    config.colors = {
        foreground = foreground_color,
        background = background_color,

        -- Cursor colors.
        cursor_bg = foreground_color,
        cursor_fg = background_color,
        cursor_border = foreground_color,

        -- Selection colors.
        selection_fg = background_color,
        selection_bg = foreground_color,

        ansi = {
            "#282828",
            "#d6000c",
            "#1d9700",
            "#c49700",
            "#0064e4",
            "#dd0f9d",
            "#00ad9c",
            "#cdcdcd",
        },
        brights = {
            "#878787",
            "#df0000",
            "#008400",
            "#af8500",
            "#0054cf",
            "#c7008b",
            "#009a8a",
            "#ebebeb",
        },
    }

    config.window_padding = {
        left = padding_px,
        right = padding_px,
        top = padding_px,
        bottom = padding_px,
    }

    config.inactive_pane_hsb = {
        saturation = 0.95,
        brightness = 0.95,
    }

    config.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }
end

return module
