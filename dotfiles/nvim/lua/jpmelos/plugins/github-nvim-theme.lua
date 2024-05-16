return {
    "projekt0n/github-nvim-theme",
    -- Make sure to load this during startup, since this is the main
    -- colorscheme.
    lazy = false,
    -- Make sure to load this before all the other plugins. This way, we can
    -- always set highlight groups in the other plugins' startup logic.
    priority = 1000,
    config = function()
        require("github-theme").setup()

        vim.cmd("colorscheme github_light")
        vim.cmd("hi Comment gui=italic guifg=#57606a guibg=none")
        vim.cmd("hi StatusLineNC gui=none guifg=#ffffff guibg=#5fafd7")
        vim.cmd("hi CursorLine gui=underline guifg=none guibg=none")
        vim.cmd("hi! link @constructor Function")
    end,
}
