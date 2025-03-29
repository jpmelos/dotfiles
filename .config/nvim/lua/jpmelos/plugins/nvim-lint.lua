-- Use a repository-local `.nvim.lua` file to overwrite this for specific
-- projects. Something like:
--
-- ```
-- local lint = require("lint")
-- lint.linters_by_ft.python = { ... }
-- ```
local linters_by_ft = {}

return {
    "mfussenegger/nvim-lint",
    cond = function()
        if #vim.tbl_keys(linters_by_ft) == 0 then
            return false
        end
        return true
    end,
    ft = vim.tbl_keys(linters_by_ft),
    config = function()
        local K = vim.keymap.set

        local lint = require("lint")

        lint.linters_by_ft = linters_by_ft

        vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
            callback = function()
                lint.try_lint()
            end,
        })

        K("n", "<leader>ll", function()
            lint.try_lint()
        end, { desc = "Lint current file" })
    end,
}
