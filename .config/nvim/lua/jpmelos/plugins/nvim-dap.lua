local waiting_for_breakpoint = nil

local function broadcast(sessions, fn)
    for _, session in pairs(sessions) do
        fn(session)
        broadcast(session.children, fn)
    end
end

local function toggle_bp_current_line()
    local api = vim.api
    local dap = require("dap")

    local bufnr = api.nvim_get_current_buf()
    local lnum = api.nvim_win_get_cursor(0)[1]
    dap.set_breakpoint()
    return { bufnr = bufnr, lnum = lnum }
end

local function unset_bp(bufnr, lnum)
    local dap = require("dap")
    local dap_breakpoints = require("dap.breakpoints")

    dap_breakpoints.toggle({ replace = true }, bufnr, lnum)
    dap_breakpoints.toggle({}, bufnr, lnum)
    local bps = dap_breakpoints.get(bufnr)
    broadcast(dap.sessions(), function(s)
        s:set_breakpoints(bps)
    end)
end

local function unset_saved_bp()
    if waiting_for_breakpoint ~= nil then
        -- Make sure it's set so toggle removes it.
        local bufnr = waiting_for_breakpoint.bufnr
        local lnum = waiting_for_breakpoint.lnum
        unset_bp(bufnr, lnum)
    end
    waiting_for_breakpoint = nil
end

local register_waiting_for_breakpoint_handler = function()
    local dap = require("dap")

    local handle_stopped_or_terminated_event = function()
        unset_saved_bp()
    end

    dap.listeners.before["event_stopped"]["jpmelos"] =
        handle_stopped_or_terminated_event
    dap.listeners.before["event_terminated"]["jpmelos"] =
        handle_stopped_or_terminated_event
end

local debug_with_host_port = function(callback, host_port)
    local host, port = host_port:match("(.-):(.*)")
    port = tonumber(port)
    if host == nil or port == nil or host == "" or port == "" then
        vim.notify("Invalid host:port configuration!", "error")
        return
    end

    callback({ type = "server", host = host, port = port })
end

local function getHostPortAndDebug(callback)
    local Input = require("nui.input")
    local event = require("nui.utils.autocmd").event

    local host_port_env = vim.g.remote_debug_debugpy_host_port
    if host_port_env == nil then
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
            on_submit = function(host_port)
                debug_with_host_port(callback, host_port)
            end,
        })

        input:on(event.BufLeave, function()
            input:unmount()
        end)
        input:map("n", "<C-c>", function()
            input:unmount()
            unset_saved_bp()
        end, { noremap = true })
        input:map("i", "<C-c>", function()
            input:unmount()
            unset_saved_bp()
        end, { noremap = true })
        input:mount()
    else
        debug_with_host_port(callback, host_port_env)
    end
end

return {
    "mfussenegger/nvim-dap",
    lazy = false,
    config = function()
        local K = vim.keymap.set

        local dap = require("dap")

        vim.g.remote_debug_debugpy_just_my_code = "true"
        vim.g.remote_debug_debugpy_path_mappings = ""
        vim.g.remote_debug_debugpy_host_port = ""

        dap.configurations.python = {
            {
                type = "debugpy",
                request = "attach",
                name = "Debug Python by attaching to debugpy",
                -- Things below are passed as arguments to debugpy.
                justMyCode = function()
                    return vim.g.remote_debug_debugpy_just_my_code
                end,
                pathMappings = function()
                    local path_mappings =
                        vim.g.remote_debug_debugpy_path_mappings
                    local dap_mappings = {}

                    if path_mappings then
                        for mapping in path_mappings:gmatch("([^;]+)") do
                            local localRoot, remoteRoot =
                                mapping:match("(.+)=(.+)")
                            table.insert(dap_mappings, {
                                localRoot = localRoot,
                                remoteRoot = remoteRoot,
                            })
                        end

                        return dap_mappings
                    end

                    return {}
                end,
            },
        }
        dap.adapters.debugpy = getHostPortAndDebug

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
        register_waiting_for_breakpoint_handler()

        K("n", "<leader>dh", dap.continue, { desc = "Continue" })
        -- This is our custom `run_to_cursor` mapping. It works even when there
        -- isn't a session running. It starts a session.
        K("n", "<leader>dr", function()
            waiting_for_breakpoint = toggle_bp_current_line()
            dap.continue()
        end, { desc = "Run to cursor" })
        K("n", "<leader>dx", dap.disconnect, { desc = "End current session" })

        K(
            "n",
            "<leader>db",
            dap.toggle_breakpoint,
            { desc = "Toggle breakpoint" }
        )

        K({ "n", "v" }, "<leader>dv", function()
            vim.cmd("vertical DapEval")
        end, { desc = "Open REPL" })

        K("n", "<leader>dj", dap.step_into, { desc = "Step into" })
        K("n", "<leader>dk", dap.step_out, { desc = "Step out" })
        K("n", "<leader>dl", dap.step_over, { desc = "Step over" })

        K("n", "<leader>dK", dap.up, { desc = "Go up in the stacktrace" })
        K("n", "<leader>dJ", dap.down, { desc = "Go down in the stacktrace" })

        K("n", "<leader>dpc", function()
            if vim.g.remote_debug_debugpy_just_my_code == "true" then
                vim.g.remote_debug_debugpy_just_my_code = "false"
            else
                vim.g.remote_debug_debugpy_just_my_code = "true"
            end
        end, { desc = "debugpy: Toggle justMyCode" })
    end,
}
