return {
    "numToStr/Comment.nvim",
    keys = {
        { "gcc", mode = "n", desc = "Toggle line comment" },
        { "gbb", mode = "n", desc = "Toggle line comment, block-style" },
        { "gc", mode = "v", desc = "Toggle selection comment " },
        { "gb", mode = "v", desc = "Toggle selection comment, block-style" },
        { "gcO", mode = "n", desc = "Add comment at line above" },
        { "gco", mode = "n", desc = "Add comment at line below" },
        { "gcA", mode = "n", desc = "Add comment at end of line" },
    },
    dependencies = {
        -- Identify correct comment syntax based on current context, with the
        -- help of tree-sitter. Supports nested languages, for example.
        "JoosepAlviste/nvim-ts-context-commentstring",
    },
    opts = function()
        return {
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
        }
    end,
}
