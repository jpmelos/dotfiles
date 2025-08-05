return {
    "LintaoAmons/scratch.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    keys = {
        {
            "<leader>xn",
            function()
                Input(
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
        {
            "<leader>xo",
            function()
                local telescope_builtins = require("telescope.builtin")
                local config_data = vim.g.scratch_config

                telescope_builtins.find_files({
                    cwd = config_data.scratch_file_dir,
                    default_text = os.date("%Y-%m-%d-"),
                })
            end,
            mode = "n",
            desc = "Open a scratch file (with today's date)",
        },
        {
            "<leader>xO",
            function()
                local telescope_builtins = require("telescope.builtin")
                local config_data = vim.g.scratch_config

                telescope_builtins.find_files({
                    cwd = config_data.scratch_file_dir,
                })
            end,
            mode = "n",
            desc = "Open a scratch file",
        },
        {
            "<leader>xe",
            "<cmd>NvimTreeOpen "
                .. vim.fn.getcwd()
                .. "/jpenv-scratch"
                .. "<CR>",
            mode = "n",
            desc = "Open the scratch folder",
        },
    },
    opts = {
        scratch_file_dir = vim.fn.getcwd() .. "/jpenv-scratch",
        window_cmd = "edit",
        use_telescope = true,
        file_picker = "telescope",
    },
}
