return {
    "iamcco/markdown-preview.nvim",
    -- This plugin doesn't work when lazy-loaded.
    lazy = false,
    keys = {
        {
            "<leader>mp",
            "<cmd>MarkdownPreview<cr>",
            mode = "n",
            desc = "Toggle Markdown preview",
        },
    },
    cmd = {
        "MarkdownPreviewToggle",
        "MarkdownPreview",
        "MarkdownPreviewStop",
    },
    init = function()
        -- Do not auto-close the preview window when closing Markdown buffer.
        vim.g.mkdp_auto_close = false
        -- Use the same window for all previews.
        vim.g.mkdp_combine_preview = true
        -- When changing the buffer, also update the preview.
        vim.g.mkdp_combine_preview_auto_refresh = true
        -- Set the browser to use in each OS.
        if vim.fn.system("uname -s"):gsub("%s+$", "") == "Darwin" then
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
    end,
    build = function()
        vim.fn["mkdp#util#install"]()
    end,
}
