local function getHostPortAndDebug(callback)
    local Input = require("nui.input")
    local event = require("nui.utils.autocmd").event

    local input = Input({
        position = "50%",
        size = { width = 40 },
        border = {
            style = "rounded",
            text = {
                top = " host:port ",
                top_align = "center",
            },
        },
        win_options = {
            winhighlight = "Normal:Normal,FloatBorder:Normal",
        },
    }, {
        prompt = "> ",
        default_value = "localhost:27027",
        on_submit = function(value)
            local host, port = value:match("(.-):(.*)")
            port = tonumber(port)
            if host == nil or port == nil or host == "" or port == "" then
                vim.notify("Invalid host:port configuration!", "error")
                return
            end

            callback({ type = "server", host = host, port = port })
        end,
    })

    input:on(event.BufLeave, function()
        input:unmount()
    end)
    input:map("n", "<Esc>", function()
        input:unmount()
    end, { noremap = true })
    input:mount()
end

return {
    "mfussenegger/nvim-dap",
    lazy = false,
    config = function()
        local K = vim.keymap.set

        local dap = require("dap")

        dap.configurations.python = {
            {
                type = "python",
                request = "attach",
                name = "Debug Python attaching to a DAP server",
                -- Things below are passed as arguments to debugpy.
                pathMappings = function()
                    if os.getenv("REMOTE_DEBUG_ROOT") then
                        return {
                            {
                                localRoot = "${workspaceFolder}",
                                remoteRoot = "${env:REMOTE_DEBUG_ROOT}",
                            },
                        }
                    end
                    return {}
                end,
            },
        }
        dap.adapters.python = getHostPortAndDebug

        vim.cmd("hi DapBreakpoint guifg=#ff0000")

        vim.fn.sign_define(
            "DapStopped",
            { text = "→", texthl = "DapBreakpoint" }
        )
        vim.fn.sign_define(
            "DapLogPoint",
            { text = "", texthl = "DapBreakpoint" }
        )
        vim.fn.sign_define(
            "DapBreakpoint",
            { text = "", texthl = "DapBreakpoint" }
        )
        vim.fn.sign_define(
            "DapBreakpointCondition",
            { text = "", texthl = "DapBreakpoint" }
        )
        vim.fn.sign_define(
            "DapBreakpointRejected",
            { text = "", texthl = "DapBreakpoint" }
        )

        K(
            "n",
            "<leader>db",
            dap.toggle_breakpoint,
            { desc = "Toggle breakpoint" }
        )
        K("n", "<leader>dh", dap.continue, { desc = "Continue" })
        K("n", "<leader>dl", dap.step_over, { desc = "Step over" })
        K("n", "<leader>dj", dap.step_into, { desc = "Step into" })
        K("n", "<leader>dk", dap.step_out, { desc = "Step out" })
        K("n", "<leader>dK", dap.up, { desc = "Go up in the stacktrace" })
        K("n", "<leader>dJ", dap.down, { desc = "Go down in the stacktrace" })
    end,
}
