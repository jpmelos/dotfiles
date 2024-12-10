return {
    "numToStr/Comment.nvim",
    lazy = false,
    dependencies = {
        -- Identify correct comment syntax based on current context, with the
        -- help of tree-sitter. Supports nested languages, for example.
        "JoosepAlviste/nvim-ts-context-commentstring",
    },
    config = function()
        require("Comment").setup({
            -- Normal mode.
            toggler = {
                line = "gcc",
                block = "gbb",
            },
            -- Visual mode.
            opleader = {
                line = "gc",
                block = "gb",
            },
            extra = {
                -- Add comment on the line above.
                above = "gcO",
                -- Add comment on the line below.
                below = "gco",
                -- Add comment at the end of line.
                eol = "gcA",
            },
            ---Function to call before (un)comment
            pre_hook = require(
                "ts_context_commentstring.integrations.comment_nvim"
            ).create_pre_hook(),
        })
    end,
}
