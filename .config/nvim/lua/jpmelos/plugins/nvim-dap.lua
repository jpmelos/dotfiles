local saved_breakpoint = nil

local function broadcast(sessions, fn)
    for _, session in pairs(sessions) do
        fn(session)
        broadcast(session.children, fn)
    end
end

local function ask_for_breakpoint_condition(on_submit_cb)
    Input("Breakpoint Condition", "", on_submit_cb)
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

local function debug_with_host_port(callback, host_port)
    local host, port = host_port:match("(.-):(.*)")
    port = tonumber(port)

    if host == nil or port == nil or host == "" or port == "" then
        vim.notify("Invalid host:port configuration!", "error")
        return
    end

    callback({ type = "server", host = host, port = port })
end

local function get_host_port_and_debug(callback)
    local host_port_env = vim.g.remote_debug_debugpy_host_port
    if host_port_env == nil then
        Input("host:port", "localhost:27027", function(host_port)
            debug_with_host_port(callback, host_port)
        end)
    else
        debug_with_host_port(callback, host_port_env)
    end
end

local function set_up_python_debugger(dap)
    local g = vim.g

    if g.remote_debug_debugpy_just_my_code == nil then
        g.remote_debug_debugpy_just_my_code = true
    end
    if g.remote_debug_debugpy_path_mappings == nil then
        g.remote_debug_debugpy_path_mappings = ""
    end
    if g.remote_debug_debugpy_host_port == nil then
        g.remote_debug_debugpy_host_port = ""
    end

    dap.configurations.python = {
        {
            type = "debugpy",
            request = "attach",
            name = "Debug Python by attaching to debugpy",
            -- Things below are passed as arguments to debugpy.
            justMyCode = function()
                if g.remote_debug_debugpy_just_my_code then
                    return "true"
                end
                return "false"
            end,
            pathMappings = function()
                local path_mappings = g.remote_debug_debugpy_path_mappings
                local dap_mappings = {}

                for mapping in path_mappings:gmatch("([^;]+)") do
                    local localRoot, remoteRoot = mapping:match("(.+)=(.+)")
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
end

local function set_up_lua_debugger(dap)
    dap.configurations.lua = {
        {
            type = "nlua",
            request = "attach",
            name = "Attach to running Neovim instance",
        },
    }
    -- Make sure this host and port matches what's configured for
    -- "jbyuki/one-small-step-for-vimkind".
    dap.adapters.nlua = function(callback)
        callback({ type = "server", host = "127.0.0.1", port = 8086 })
    end
end

return {
    "mfussenegger/nvim-dap",
    dependencies = {
        -- We use this in our custom setup for this plugin.
        "MunifTanjim/nui.nvim",
    },
    keys = {
        { "<leader>dr", mode = "n", desc = "Run to cursor" },
        { "<leader>dR", mode = "n", desc = "Run to cursor conditionally" },
        { "<leader>db", mode = "n", desc = "Toggle breakpoint" },
        { "<leader>dB", mode = "n", desc = "Toggle conditional breakpoint" },
        { "<leader>dp", mode = "n", desc = "debugpy: Toggle justMyCode" },
    },
    config = function()
        local K = vim.keymap.set

        local dap = require("dap")
        set_up_python_debugger(dap)
        set_up_lua_debugger(dap)

        vim.cmd("hi DapBreakpoint guifg=#ff0000")

        -- TODO: These are causing `vim.deprecated` warnings.
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

        -- TODO: Find out why these sometimes don't work.
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

        K("n", "<leader>dp", function()
            vim.g.remote_debug_debugpy_just_my_code =
                not vim.g.remote_debug_debugpy_just_my_code
        end, { desc = "debugpy: Toggle justMyCode" })
    end,
}
