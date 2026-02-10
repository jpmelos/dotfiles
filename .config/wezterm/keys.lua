local wezterm = require("wezterm")
local action = wezterm.action
local module = {}

local process_integration = require("process-integration")

local function bind_if_else(cond, key, mods, if_action, else_action)
    local function callback(win, pane)
        if cond(pane) then
            win:perform_action(if_action, pane)
        else
            win:perform_action(else_action, pane)
        end
    end

    return {
        key = key,
        mods = mods,
        action = wezterm.action_callback(callback),
    }
end

local function bind_if(cond, key, mods, if_action)
    return bind_if_else(
        cond,
        key,
        mods,
        if_action,
        action.SendKey({ key = key, mods = mods })
    )
end

function module.apply_to_config(config)
    config.disable_default_key_bindings = true

    config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 10000 }

    config.keys = {
        -- Configuration.
        {
            key = "r",
            mods = "LEADER",
            action = action.ReloadConfiguration,
        },
        -- Enter for new lines in Claude.
        -- SHIFT + Enter to send the prompt in Claude.
        bind_if(
            process_integration.is_in_claude,
            "Enter",
            "",
            wezterm.action({ SendString = "\x1b\r" })
        ),
        bind_if(
            process_integration.is_in_claude,
            "Enter",
            "SHIFT",
            wezterm.action({ SendString = "\r" })
        ),
        -- Clear screen.
        bind_if(
            process_integration.is_outside_vim,
            "n",
            "CTRL",
            action.SendKey({ key = "L", mods = "CTRL" })
        ),
        -- Copy mode.
        {
            key = "Enter",
            mods = "LEADER",
            action = action.ActivateCopyMode,
        },
        -- Search.
        {
            key = "f",
            mods = "SUPER",
            action = action.Search("CurrentSelectionOrEmptyString"),
        },
        -- Clipboard.
        -- Disable `cmd+c` in Neovim to train muscle memory to use `y` instead.
        bind_if_else(
            process_integration.is_outside_vim,
            "c",
            "SUPER",
            action.CopyTo("Clipboard"),
            action.Nop
        ),
        -- Disable `cmd+v` in Neovim to train muscle memory to use `p` instead.
        bind_if_else(
            process_integration.is_outside_vim,
            "v",
            "SUPER",
            action.PasteFrom("Clipboard"),
            action.Nop
        ),
        -- Tabs.
        {
            key = "c",
            mods = "LEADER",
            action = action.SpawnTab("CurrentPaneDomain"),
        },
        {
            key = "j",
            mods = "CTRL|META",
            action = action.ActivateTabRelativeNoWrap(-1),
        },
        {
            key = "k",
            mods = "CTRL|META",
            action = action.ActivateTabRelativeNoWrap(1),
        },
        {
            key = "u",
            mods = "CTRL|META",
            action = action.MoveTabRelative(-1),
        },
        {
            key = "i",
            mods = "CTRL|META",
            action = action.MoveTabRelative(1),
        },
        -- Scrolling.
        {
            key = "j",
            mods = "ALT",
            action = action.ScrollByPage(0.5),
        },
        {
            key = "k",
            mods = "ALT",
            action = action.ScrollByPage(-0.5),
        },
        -- Panes.
        {
            key = "v",
            mods = "LEADER",
            action = action.SplitPane({ direction = "Right" }),
        },
        {
            key = "v",
            mods = "LEADER|SHIFT",
            action = action.SplitPane({
                direction = "Right",
                size = { Cells = 80 },
                top_level = true,
            }),
        },
        {
            key = "x",
            mods = "LEADER",
            action = action.SplitPane({ direction = "Down" }),
        },
        {
            key = "x",
            mods = "LEADER|SHIFT",
            action = action.SplitPane({
                direction = "Down",
                size = { Percent = 25 },
            }),
        },
        bind_if(
            process_integration.is_outside_vim,
            "h",
            "CTRL",
            action.ActivatePaneDirection("Left")
        ),
        bind_if(
            process_integration.is_outside_vim,
            "j",
            "CTRL",
            action.ActivatePaneDirection("Down")
        ),
        bind_if(
            process_integration.is_outside_vim,
            "k",
            "CTRL",
            action.ActivatePaneDirection("Up")
        ),
        bind_if(
            process_integration.is_outside_vim,
            "l",
            "CTRL",
            action.ActivatePaneDirection("Right")
        ),
        -- Debug overlay.
        { key = "l", mods = "SHIFT|CTRL", action = action.ShowDebugOverlay },
    }

    config.key_tables = {
        copy_mode = {
            -- Quit.
            {
                key = "Enter",
                mods = "LEADER",
                action = action.CopyMode("Close"),
            },
            {
                key = "c",
                mods = "CTRL",
                action = action.CopyMode("Close"),
            },
            -- Movement.
            { key = "h", action = action.CopyMode("MoveLeft") },
            { key = "j", action = action.CopyMode("MoveDown") },
            { key = "k", action = action.CopyMode("MoveUp") },
            { key = "l", action = action.CopyMode("MoveRight") },
            {
                key = "u",
                mods = "CTRL",
                action = action.CopyMode({ MoveByPage = -0.5 }),
            },
            {
                key = "d",
                mods = "CTRL",
                action = action.CopyMode({ MoveByPage = 0.5 }),
            },
            {
                key = "0",
                action = action.CopyMode("MoveToStartOfLine"),
            },
            {
                key = "_",
                action = action.CopyMode("MoveToStartOfLineContent"),
            },
            {
                key = "$",
                action = action.CopyMode("MoveToEndOfLineContent"),
            },
            {
                key = "w",
                action = action.CopyMode("MoveForwardWord"),
            },
            {
                key = "b",
                action = action.CopyMode("MoveBackwardWord"),
            },
            -- Selection mode.
            {
                key = "v",
                action = action.CopyMode({ SetSelectionMode = "Cell" }),
            },
            {
                key = "v",
                mods = "SHIFT",
                action = action.CopyMode({ SetSelectionMode = "Line" }),
            },
            {
                key = "v",
                mods = "CTRL",
                action = action.CopyMode({ SetSelectionMode = "Block" }),
            },
            -- Copy.
            {
                key = "y",
                action = action.Multiple({
                    action.CopyTo("Clipboard"),
                    action.ClearSelection,
                    action.CopyMode("ClearSelectionMode"),
                }),
            },
        },
    }
end

return module
