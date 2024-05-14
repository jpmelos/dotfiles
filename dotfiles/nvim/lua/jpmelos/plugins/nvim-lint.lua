return {
    "mfussenegger/nvim-lint",
    lazy = false,
    config = function()
        local K = vim.keymap.set

        local lint = require("lint")

        lint.linters_by_ft = {}

        vim.api.nvim_create_autocmd(
            { "FocusGained", "BufEnter", "BufWritePost", "InsertLeave" },
            {
                group = vim.api.nvim_create_augroup("lint", { clear = true }),
                callback = function()
                    lint.try_lint()
                end,
            }
        )

        K("n", "<leader>lt", function()
            lint.try_lint()
        end, { desc = "Lint current file" })
    end,
}
