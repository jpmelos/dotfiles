return {
    "ruifm/gitlinker.nvim",
    lazy = false,
    config = function()
        local K = vim.keymap.set

        require("gitlinker").setup({ mappgins = nil })

        vim.api.nvim_create_user_command("GetGitLink", function()
            require("gitlinker").get_buf_range_url("n", {
                action_callback = function(url)
                    vim.cmd('let @+ = "' .. url .. '"')
                    require("gitlinker.actions").open_in_browser(url)
                end,
            })
        end, {})
        vim.api.nvim_create_user_command("GetGitLinkV", function()
            require("gitlinker").get_buf_range_url("v", {
                action_callback = function(url)
                    vim.cmd('let @+ = "' .. url .. '"')
                    require("gitlinker.actions").open_in_browser(url)
                end,
            })
        end, {})

        K(
            "n",
            "<leader>gy",
            "<cmd>GetGitLink<CR>",
            { desc = "Copy permalink" }
        )
        K("n", "gy", "<cmd>GetGitLink<CR>", { desc = "Copy permalink" })
        K(
            "v",
            "<leader>gy",
            "<cmd>GetGitLinkV<CR>",
            { desc = "Copy permalink" }
        )
        K("v", "gy", "<cmd>GetGitLinkV<CR>", { desc = "Copy permalink" })
    end,
}
