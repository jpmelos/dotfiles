local wezterm = require("wezterm")
local action = wezterm.action
local module = {}

local nvim_integration = require("nvim-integration")

local function bind_if(cond, key, mods, navigate_action)
    local function callback(win, pane)
        if cond(pane) then
            win:perform_action(navigate_action, pane)
        else
            win:perform_action(
                action.SendKey({ key = key, mods = mods }),
                pane
            )
        end
    end

    return {
        key = key,
        mods = mods,
        action = wezterm.action_callback(callback),
    }
end

function module.apply_to_config(config)
    config.disable_default_key_bindings = true

    config.enable_kitty_keyboard = true

    config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 10000 }

    config.keys = {
        -- Configuration.
        {
            key = "r",
            mods = "LEADER",
            action = action.ReloadConfiguration,
        },
        -- Clear screen.
        bind_if(
            nvim_integration.is_outside_vim,
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
        {
            key = "c",
            mods = "SUPER",
            action = action.CopyTo("Clipboard"),
        },
        {
            key = "v",
            mods = "SUPER",
            action = action.PasteFrom("Clipboard"),
        },
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
        -- Panes.
        {
            key = "v",
            mods = "LEADER",
            action = action.SplitPane({
                direction = "Right",
            }),
        },
        {
            key = "v",
            mods = "LEADER|SHIFT",
            action = action.SplitPane({
                direction = "Right",
                size = { Percent = 25 },
            }),
        },
        {
            key = "x",
            mods = "LEADER",
            action = action.SplitPane({
                direction = "Down",
            }),
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
            nvim_integration.is_outside_vim,
            "h",
            "CTRL",
            action.ActivatePaneDirection("Left")
        ),
        bind_if(
            nvim_integration.is_outside_vim,
            "j",
            "CTRL",
            action.ActivatePaneDirection("Down")
        ),
        bind_if(
            nvim_integration.is_outside_vim,
            "k",
            "CTRL",
            action.ActivatePaneDirection("Up")
        ),
        bind_if(
            nvim_integration.is_outside_vim,
            "l",
            "CTRL",
            action.ActivatePaneDirection("Right")
        ),
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
                    { CopyTo = "Clipboard" },
                    { CopyMode = "Close" },
                }),
            },
        },
    }
end

return module
