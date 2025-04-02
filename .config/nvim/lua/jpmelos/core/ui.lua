function Input(title, default_value, callback)
    local Input = require("nui.input")
    local event = require("nui.utils.autocmd").event

    local input = Input({
        position = "50%",
        size = { width = 80 },
        border = {
            style = "rounded",
            text = {
                top = " " .. title .. " ",
                top_align = "center",
            },
        },
        win_options = {
            winhighlight = "Normal:Normal,FloatBorder:Normal",
        },
    }, {
        default_value = default_value,
        on_submit = callback,
    })

    input:on(event.BufLeave, function()
        input:unmount()
    end)

    input:map("n", "q", function()
        input:unmount()
    end, { noremap = true })

    input:mount()
end

return { Input = Input }
