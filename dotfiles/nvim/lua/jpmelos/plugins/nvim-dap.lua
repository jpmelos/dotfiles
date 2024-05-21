local function broadcast(sessions, fn)
    for _, session in pairs(sessions) do
        fn(session)
        broadcast(session.children, fn)
    end
end

local function toggle_bp_current_line(api, dap)
    local bufnr = api.nvim_get_current_buf()
    local lnum = api.nvim_win_get_cursor(0)[1]
    dap.set_breakpoint()
    return { bufnr = bufnr, lnum = lnum }
end

local function unset_bp_current_line(dap, dap_breakpoints, bufnr, lnum)
    dap_breakpoints.toggle({ replace = true }, bufnr, lnum)
    dap_breakpoints.toggle({}, bufnr, lnum)
    local bps = dap_breakpoints.get(bufnr)
    broadcast(dap.sessions(), function(s)
        s:set_breakpoints(bps)
    end)
end

-- Things used in the `run_to_cursor` keymap binding.
local waiting_for_breakpoint = nil
local register_waiting_for_breakpoint_handler = function(dap, dap_breakpoints)
    dap.listeners.before["event_stopped"]["jpmelos"] = function()
        if waiting_for_breakpoint ~= nil then
            -- Make sure it's set so toggle removes it.
            local bufnr = waiting_for_breakpoint.bufnr
            local lnum = waiting_for_breakpoint.lnum
            unset_bp_current_line(dap, dap_breakpoints, bufnr, lnum)
        end
        waiting_for_breakpoint = nil
    end
end

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
        local api = vim.api
        local K = vim.keymap.set

        local dap = require("dap")
        local dap_breakpoints = require("dap.breakpoints")

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

        -- Register handler to handle our `run_to_cursor`.
        register_waiting_for_breakpoint_handler(dap, dap_breakpoints)

        K("n", "<leader>dh", dap.continue, { desc = "Continue" })
        -- This is our custom `run_to_cursor` mapping. It works even when there
        -- isn't a session running. It starts a session.
        K("n", "<leader>dr", function()
            waiting_for_breakpoint = toggle_bp_current_line(api, dap)
            dap.continue()
        end, { desc = "Run to cursor" })
        K("n", "<leader>dx", dap.disconnect, { desc = "End current session" })
        K(
            "n",
            "<leader>db",
            dap.toggle_breakpoint,
            { desc = "Toggle breakpoint" }
        )
        K("n", "<leader>dl", dap.step_over, { desc = "Step over" })
        K("n", "<leader>dj", dap.step_into, { desc = "Step into" })
        K("n", "<leader>dk", dap.step_out, { desc = "Step out" })
        K("n", "<leader>dK", dap.up, { desc = "Go up in the stacktrace" })
        K("n", "<leader>dJ", dap.down, { desc = "Go down in the stacktrace" })
    end,
}
