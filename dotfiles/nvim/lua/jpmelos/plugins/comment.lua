return {
    "numToStr/Comment.nvim",
    lazy = false,
    dependencies = {
        -- Identify correct comment syntax based on current context, with the
        -- help of tree-sitter.
        "JoosepAlviste/nvim-ts-context-commentstring",
    },
    config = function()
        require("Comment").setup({
            pre_hook = require(
                "ts_context_commentstring.integrations.comment_nvim"
            ).create_pre_hook(),
        })
    end,
}
