-- How to use this:
-- 1. Start the Neovim instance that you want to debug.
-- 2. Start the Neovim debugger server as below.
-- 3. Start another Neovim instance, this will be the instance you'll use to
--    follow along the running code.
-- 4. Set breakpoints and watch the code run. :-)
return {
    "jbyuki/one-small-step-for-vimkind",
    keys = {
        {
            "<leader>dn",
            function()
                -- Make sure this host and port matches what's configured for
                -- "nvim-dap".
                require("osv").launch({ port = 8086 })
            end,
            mode = "n",
            desc = "Start Neovim debugger",
        },
    },
}
