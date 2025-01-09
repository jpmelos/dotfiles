return {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    config = function()
        local K = vim.keymap.set

        local dap = require("dap")
        local dapui = require("dapui")

        ---@diagnostic disable-next-line: missing-fields
        dapui.setup({
            ---@diagnostic disable-next-line: missing-fields
            controls = { enabled = false },
            layouts = {
                {
                    elements = {
                        { id = "scopes", size = 0.25 },
                        { id = "breakpoints", size = 0.25 },
                        { id = "stacks", size = 0.25 },
                        { id = "watches", size = 0.25 },
                    },
                    position = "left",
                    size = 40,
                },
                {
                    elements = { { id = "repl", size = 1 } },
                    position = "bottom",
                    size = 20,
                },
            },
        })

        dap.listeners.before.attach.dapui_config = function()
            dapui.open()
        end
        dap.listeners.before.launch.dapui_config = function()
            dapui.open()
        end
        dap.listeners.before.event_terminated.dapui_config = function()
            dapui.close()
        end
        dap.listeners.before.event_exited.dapui_config = function()
            dapui.close()
        end

        K("n", "<leader>do", function()
            dapui.open({ reset = true })
        end, { desc = "Open DAP UI" })
        K("n", "<leader>dc", dapui.close, { desc = "Close DAP UI" })

        K({ "n", "v" }, "<leader>de", function()
            ---@diagnostic disable-next-line: missing-fields
            dapui.eval(nil, { enter = true })
        end, { desc = "Evaluate under cursor" })
    end,
}
