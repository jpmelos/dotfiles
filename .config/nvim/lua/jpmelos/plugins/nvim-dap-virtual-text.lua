return {
    "theHamsta/nvim-dap-virtual-text",
    lazy = true,
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "mfussenegger/nvim-dap",
    },
    opts = {
        -- Show value in every definition. This doesn't mean it will show
        -- it for every reference. There's another setting for that.
        only_first_definition = false,
        virt_text_pos = "eol",
        virt_lines = true,
        display_callback = function(variable)
            local text = variable.name .. " = " .. variable.value

            if #text > 79 then
                return string.sub(text, 1, 76) .. "..."
            end
            return text
        end,
    },
}
