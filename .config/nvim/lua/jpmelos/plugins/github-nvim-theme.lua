return {
    "projekt0n/github-nvim-theme",
    -- Make sure to load this before all the other plugins. This way, we can
    -- always set highlight groups in the other plugins' startup logic.
    priority = 1000,
    config = function()
        require("github-theme").setup()

        -- Use the `github_light` theme from this colorscheme.
        vim.cmd("colorscheme github_light")

        vim.cmd("hi Normal guibg=#fafafa")
        vim.cmd("hi NormalNC guibg=#fafafa")

        -- Customize inactive status line, to make it appear. By default, it is
        -- invisible in this theme.
        vim.cmd("hi StatusLine gui=none guifg=#f6f8fa guibg=#5094e4")
        vim.cmd("hi StatusLineNC gui=none guifg=#f6f8fa guibg=#5fafd7")
        vim.cmd("hi TabLineFill gui=none guifg=#f6f8fa guibg=#5094e4")

        -- Make the cursor line have a gray background.
        vim.cmd("hi CursorLine gui=none guifg=none guibg=#eeeeee")
        vim.cmd("hi ColorColumn gui=none guifg=none guibg=#dadada")

        -- Make strings show in green.
        vim.cmd("hi String gui=none guifg=#006900")

        -- Make constructors show as regular function calls.
        vim.cmd("hi! link @constructor Function")

        -- Code syntax improvements.
        vim.cmd("hi @variable.member gui=none guifg=none guibg=none")
        vim.cmd("hi Function gui=none guifg=none guibg=none")
        vim.cmd("hi @type gui=none guifg=none guibg=none")
        vim.cmd("hi Operator gui=none guifg=none guibg=none")
        vim.cmd("hi @module gui=none guifg=none guibg=none")

        -- Make comments and string documentation (like docstrings in Python)
        -- show in italic.
        vim.cmd("hi Comment gui=italic")
        vim.cmd("hi @string.documentation gui=italic")
        vim.cmd("hi TodoFgNOTE guifg=#646464")

        -- Git commit temporary file.
        vim.cmd("hi diffAdded guibg=none")
        vim.cmd("hi diffremoved guibg=none")
        vim.cmd("hi Special guifg=none")
    end,
}
