return {
    "linrongbin16/lsp-progress.nvim",
    lazy = false,
    dependencies = { "neovim/nvim-lspconfig" },
    config = function()
        require("lsp-progress").setup({
            -- Make sure messages stay visible for 5 seconds since the last
            -- update.
            decay = 5000,
            -- Update the status line every second, by emitting the
            -- `User.LspProgressStatusUpdated` event.
            regular_internal_update_time = 1000,
        })

        -- Create a VimL function that we can call from the statusline option.
        vim.api.nvim_exec2(
            [[
                function! LspStatus() abort
                    if luaeval("#vim.lsp.get_clients() > 0")
                        return luaeval("require('lsp-progress').progress()")
                    endif
                    return ""
                endfunction
            ]],
            {}
        )

        -- Redraw the status line every time we get this event, which is
        -- emitted every second or when there are LSP events.
        vim.api.nvim_create_autocmd("User", {
            pattern = "LspProgressStatusUpdated",
            command = "redrawstatus",
        })
    end,
}
