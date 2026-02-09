return {
    "ruifm/gitlinker.nvim",
    config = function()
        local K = vim.keymap.set

        require("gitlinker").setup({ mappgins = nil })

        vim.api.nvim_create_user_command("GetGitLink", function()
            require("gitlinker").get_buf_range_url(vim.fn.mode():lower(), {
                action_callback = function(url)
                    -- Fix single-line ranges: #LX-LX should become #LX.
                    url = url:gsub("#L(%d+)%-L%1", "#L%1")
                    vim.cmd('let @+ = "' .. url .. '"')
                    require("gitlinker.actions").open_in_browser(url)
                    NormalMode()
                end,
            })
        end, {})

        K(
            { "n", "v" },
            "gy",
            "<cmd>GetGitLink<CR>",
            { desc = "Copy permalink" }
        )
    end,
}
