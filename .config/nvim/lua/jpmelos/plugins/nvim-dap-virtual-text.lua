return {
    "theHamsta/nvim-dap-virtual-text",
    dependencies = {
        "nvim-treesitter/nvim-treesitter",
        "mfussenegger/nvim-dap",
    },
    keys = function(_, opts)
        return require("lazy.core.config").spec.plugins["nvim-dap"].keys
    end,
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
