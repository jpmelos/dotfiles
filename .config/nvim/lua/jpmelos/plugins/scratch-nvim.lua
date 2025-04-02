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
                local Input = require("nui.input")
                local event = require("nui.utils.autocmd").event

                local input = Input({
                    position = "50%",
                    size = { width = 80 },
                    border = {
                        style = "rounded",
                        text = {
                            top = " Scratch File Name ",
                            top_align = "center",
                        },
                    },
                    win_options = {
                        winhighlight = "Normal:Normal,FloatBorder:Normal",
                    },
                }, {
                    default_value = os.date("%Y-%m-%d-"),
                    on_submit = function(filename)
                        if filename ~= nil and filename ~= "" then
                            require("scratch.api").createScratchFileByName(
                                filename
                            )
                            vim.cmd("startinsert")
                        end
                    end,
                })

                input:on(event.BufLeave, function()
                    input:unmount()
                end)

                input:map("n", "q", function()
                    input:unmount()
                end, { noremap = true })

                input:mount()
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
