return {
    "iamcco/markdown-preview.nvim",
    -- This plugin doesn't work when lazy-loaded.
    lazy = false,
    keys = {
        {
            "<leader>mp",
            "<cmd>MarkdownPreview<cr>",
            mode = "n",
            desc = "Open Markdown preview",
        },
    },
    init = function()
        -- Do not auto-close the preview window when closing Markdown buffer.
        vim.g.mkdp_auto_close = true
        -- Use the same window for all previews.
        vim.g.mkdp_combine_preview = true
        -- When changing the buffer, also update the preview.
        vim.g.mkdp_combine_preview_auto_refresh = true
        -- Set up browser opening without stealing focus.
        if Trim(vim.fn.system("uname -s")) == "Darwin" then
            -- macOS: Use `open -g` to open in background without focus.
            vim.cmd([[
                function! OpenMarkdownPreviewBrowser(url)
                    silent execute "!open -g -a Firefox " . shellescape(a:url)
                endfunction
            ]])
            vim.g.mkdp_browserfunc = "OpenMarkdownPreviewBrowser"
        else
            -- Linux
            vim.notify(
                "Fix this, make it specific for Linux in"
                    .. " markdown-preview.nvim."
            )
            vim.g.mkdp_browser = ""
        end
    end,
    build = function()
        vim.fn["mkdp#util#install"]()
    end,
}
