return {
    "numToStr/Comment.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
        -- Identify correct comment syntax based on current context, with the
        -- help of tree-sitter.
        "JoosepAlviste/nvim-ts-context-commentstring",
    },
    config = function()
        local comment = require("Comment")
        local ts_context_commentstring =
            require("ts_context_commentstring.integrations.comment_nvim")

        comment.setup({
            pre_hook = ts_context_commentstring.create_pre_hook(),
        })
    end,
}
