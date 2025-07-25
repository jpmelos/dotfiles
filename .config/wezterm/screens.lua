local module = {}

function module.get_screen_width(win)
    local dpi_baseline = 72 -- MacOS: 72. Linux: 96.
    local dimensions = win:get_dimensions()

    local dpi_conversion_rate = dimensions.dpi / dpi_baseline

    return dimensions.pixel_width / dpi_conversion_rate
end

return module
