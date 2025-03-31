-- Use a repository-local `.nvim.lua` file to configure linters for specific
-- projects. Something like:
-- ```
-- vim.g.linters_by_ft = { python = { ... } }
-- ```
if vim.g.linters_by_ft == nil then
    vim.g.linters_by_ft = {}
end

return {
    "mfussenegger/nvim-lint",
    cond = function()
        if #vim.tbl_keys(vim.g.linters_by_ft) == 0 then
            return false
        end
        return true
    end,
    ft = vim.tbl_keys(vim.g.linters_by_ft),
    config = function()
        local K = vim.keymap.set

        local lint = require("lint")

        lint.linters_by_ft = vim.g.linters_by_ft

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
