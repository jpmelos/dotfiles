return {
    "projekt0n/github-nvim-theme",
    -- Make sure to load this during startup, since this is the main colorscheme.
    lazy = false,
    -- Make sure to load this before all the other startup plugins.
    priority = 1000,
    config = function()
        require("github-theme").setup({
            options = {
                darken = {
                    floats = true,
                },
            },
        })

        vim.cmd("colorscheme github_light")
    end,
}
