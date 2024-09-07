return {
    "mfussenegger/nvim-lint",
    lazy = false,
    config = function()
        local K = vim.keymap.set

        local lint = require("lint")

        lint.linters_by_ft = {}

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
