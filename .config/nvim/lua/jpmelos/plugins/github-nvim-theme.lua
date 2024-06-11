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

        -- Use the `github_light` theme from this colorscheme.
        vim.cmd("colorscheme github_light")

        -- Customize inactive status line, to make it appear. By default, it is
        -- invisible in this theme.
        vim.cmd("hi StatusLine gui=none guifg=#f6f8fa guibg=#5094e4")
        vim.cmd("hi StatusLineNC gui=none guifg=#ffffff guibg=#5fafd7")
        vim.cmd("hi TabLineFill gui=none guifg=#f6f8fa guibg=#5094e4")

        -- Make the cursor line be underlined and have no background color.
        vim.cmd("hi CursorLine gui=none guifg=none guibg=#eeeeee")
        vim.cmd("hi ColorColumn gui=none guifg=none guibg=#dadada")

        -- Make constructors show as regular function calls.
        vim.cmd("hi! link @constructor Function")

        -- Code syntax improvements.
        vim.cmd("hi @variable.member gui=none guifg=none guibg=none")
        vim.cmd("hi Function gui=none guifg=none guibg=none")
        vim.cmd("hi @type gui=none guifg=none guibg=none")
        vim.cmd("hi Operator gui=none guifg=none guibg=none")

        -- Make comments and string documentation (like docstrings in Python)
        -- show in italic.
        vim.cmd("hi Comment gui=italic")
        vim.cmd("hi @string.documentation gui=italic")

        -- Git commit temporary file.
        vim.cmd("hi diffAdded guibg=none")
        vim.cmd("hi diffremoved guibg=none")
        vim.cmd("hi Special guifg=none")
    end,
}
