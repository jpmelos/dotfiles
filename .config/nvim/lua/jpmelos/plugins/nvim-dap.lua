local saved_breakpoint = nil

local function broadcast(sessions, fn)
    for _, session in pairs(sessions) do
        fn(session)
        broadcast(session.children, fn)
    end
end

local function ask_for_breakpoint_condition(on_submit_cb)
    local Input = require("nui.input")
    local event = require("nui.utils.autocmd").event

    local input = Input({
        position = "50%",
        size = { width = 80 },
        border = {
            style = "rounded",
            text = {
                top = " Breakpoint Condition ",
                top_align = "center",
            },
        },
        win_options = {
            winhighlight = "Normal:Normal,FloatBorder:Normal",
        },
    }, {
        prompt = "> ",
        on_submit = on_submit_cb,
    })

    input:on(event.BufLeave, function()
        input:unmount()
    end)

    input:map("n", "<C-c>", function()
        input:unmount()
    end, { noremap = true })
    input:map("i", "<C-c>", function()
        input:unmount()
    end, { noremap = true })

    input:mount()
end

local function toggle_breakpoint(ask_for_condition)
    local dap = require("dap")

    if ask_for_condition then
        ask_for_breakpoint_condition(function(condition)
            local condition_hit = tonumber(condition)
            if condition_hit then
                dap.toggle_breakpoint(nil, condition)
                return
            end

            if condition ~= "" and condition ~= nil then
                dap.toggle_breakpoint(condition)
                return
            end

            dap.toggle_breakpoint()
        end)
    else
        dap.toggle_breakpoint()
    end
end

local function set_saved_breakpoint_and_run(ask_for_condition)
    local api = vim.api
    local dap = require("dap")

    local bufnr = api.nvim_get_current_buf()
    local lnum = api.nvim_win_get_cursor(0)[1]
    saved_breakpoint = { bufnr = bufnr, lnum = lnum }

    if ask_for_condition then
        ask_for_breakpoint_condition(function(condition)
            local condition_hit = tonumber(condition)
            if condition_hit then
                dap.set_breakpoint(nil, condition)
                dap.continue()
                return
            end

            if condition ~= "" and condition ~= nil then
                dap.set_breakpoint(condition)
                dap.continue()
                return
            end

            dap.set_breakpoint()
            dap.continue()
        end)
    else
        dap.set_breakpoint()
        dap.continue()
    end
end

local function unset_saved_breakpoint()
    local dap = require("dap")
    local dap_breakpoints = require("dap.breakpoints")

    if saved_breakpoint == nil then
        return
    end

    local bufnr = saved_breakpoint.bufnr
    local lnum = saved_breakpoint.lnum

    dap_breakpoints.toggle({ replace = true }, bufnr, lnum)
    dap_breakpoints.toggle({}, bufnr, lnum)
    local bps = dap_breakpoints.get(bufnr)
    broadcast(dap.sessions(), function(s)
        s:set_breakpoints(bps)
    end)
end

local function register_event_handlers()
    local dap = require("dap")

    local function handle_initialized_event()
        OpenCurrentBufferInNewTab()
    end

    local function handle_stopped_event()
        unset_saved_breakpoint()
    end

    local function handle_terminated_event()
        unset_saved_breakpoint()
        vim.cmd("tabclose")
    end

    dap.listeners.before["event_initialized"]["jpmelos"] =
        handle_initialized_event
    dap.listeners.before["event_stopped"]["jpmelos"] = handle_stopped_event
    dap.listeners.before["event_terminated"]["jpmelos"] =
        handle_terminated_event
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

local function get_host_port_and_debug(callback)
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
        end, { noremap = true })
        input:map("i", "<C-c>", function()
            input:unmount()
        end, { noremap = true })
        input:mount()
    else
        debug_with_host_port(callback, host_port_env)
    end
end

return {
    "mfussenegger/nvim-dap",
    dependencies = {
        -- We use this in our custom setup for this plugin.
        "MunifTanjim/nui.nvim",
    },
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

                    for mapping in path_mappings:gmatch("([^;]+)") do
                        local localRoot, remoteRoot =
                            mapping:match("(.+)=(.+)")
                        table.insert(dap_mappings, {
                            localRoot = localRoot,
                            remoteRoot = remoteRoot,
                        })
                    end

                    return dap_mappings
                end,
            },
        }
        dap.adapters.debugpy = get_host_port_and_debug

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
        register_event_handlers()
        -- This is our custom `run_to_cursor` mapping. It works even when there
        -- isn't a session running: it starts a session.
        K("n", "<leader>dr", function()
            set_saved_breakpoint_and_run()
        end, { desc = "Run to cursor" })
        K("n", "<leader>dR", function()
            set_saved_breakpoint_and_run(true)
        end, { desc = "Run to cursor conditionally" })
        K("n", "<leader>dx", dap.disconnect, { desc = "End current session" })

        K("n", "<leader>db", toggle_breakpoint, { desc = "Toggle breakpoint" })
        K("n", "<leader>dB", function()
            toggle_breakpoint(true)
        end, { desc = "Toggle conditional breakpoint" })

        K({ "n", "v" }, "<leader>dv", function()
            vim.cmd("vertical DapEval")
        end, { desc = "Open REPL" })

        K("n", "<leader>dh", dap.continue, { desc = "Continue" })
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
