return {
    "LintaoAmons/scratch.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    keys = {
        {
            "<leader>xo",
            "<cmd>ScratchOpen<cr>",
            mode = "n",
            desc = "Open a scratch file",
        },
        {
            "<leader>xn",
            function()
                require("jpmelos.core.ui").Input(
                    "Scratch File Name",
                    os.date("%Y-%m-%d-"),
                    function(filename)
                        if filename ~= nil and filename ~= "" then
                            require("scratch.api").createScratchFileByName(
                                filename
                            )
                            vim.cmd("startinsert")
                        end
                    end
                )
            end,
            mode = "n",
            desc = "Create a new scratch file",
        },
    },
    opts = {
        scratch_file_dir = vim.fn.getcwd() .. "/jpenv-scratch",
        window_cmd = "vsplit",
        use_telescope = true,
        file_picker = "telescope",
    },
}
