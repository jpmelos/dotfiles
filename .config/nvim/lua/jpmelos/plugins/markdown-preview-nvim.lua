return {
    "iamcco/markdown-preview.nvim",
    init = function()
        local K = vim.keymap.set

        -- Do not auto-close the preview window when closing Markdown buffer.
        vim.g.mkdp_auto_close = false
        -- Use the same window for all previews.
        vim.g.mkdp_combine_preview = true
        -- When changing the buffer, also update the preview.
        vim.g.mkdp_combine_preview_auto_refresh = true
        -- Set the browser to use in each OS.
        if vim.loop.os_uname().sysname == "Darwin" then
            -- MacOS
            vim.g.mkdp_browser =
                "/Applications/Firefox.app/Contents/MacOS/firefox"
        else
            -- Linux
            vim.notify(
                "Fix this, make it specific for Linux in"
                    .. " markdown-preview.nvim."
            )
            vim.g.mkdp_browser = ""
        end

        K(
            "n",
            "<leader>mp",
            "<cmd>MarkdownPreviewToggle<cr>",
            { desc = "Toggle Markdown preview" }
        )
    end,
    build = function()
        vim.fn["mkdp#util#install"]()
    end,
}
