-- Use a repository-local `.nvim.lua` file to configure linters for specific
-- projects. Like this:
-- ```
-- vim.g.linters_by_ft = { rust = { ... } }
-- ```
-- If all you need is to override some values from the default configuration,
-- do it like this. Changing `vim.g.linters_by_ft` directly doesn't work as
-- expected:
-- ```
-- local linters_by_ft = vim.g.linters_by_ft
-- linters_by_ft.rust = { ... }
-- vim.g.linters_by_ft = linters_by_ft
-- ```
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

        lint.linters.clippy.args = {
            "clippy",
            "--message-format=json",
            "--all-targets",
            "--all-features",
        }

        lint.linters_by_ft = vim.g.linters_by_ft

        vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
            callback = function(args)
                local filetype =
                    vim.api.nvim_buf_get_option(args.buf, "filetype")
                if vim.g.linters_by_ft[filetype] then
                    lint.try_lint()
                end
            end,
        })

        K("n", "<leader>ll", function()
            lint.try_lint()
        end, { desc = "Lint current file" })
    end,
}
