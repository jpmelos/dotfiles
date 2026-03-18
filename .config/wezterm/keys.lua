local wezterm = require("wezterm")
local action = wezterm.action
local module = {}

local process_integration = require("process_integration")
local aoe_integration = require("aoe_integration")

local function bind_if_else(mods, key, cond, if_action, else_action)
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

local function bind_if_else_forward(mods, key, cond, if_action)
    return bind_if_else(
        mods,
        key,
        cond,
        if_action,
        action.SendKey({ key = key, mods = mods })
    )
end

function module.apply_to_config(config)
    config.disable_default_key_bindings = true

    config.leader = { key = "a", mods = "CTRL", timeout_milliseconds = 10000 }

    config.mouse_bindings = {
        -- Require SHIFT+CLICK for opening links.
        {
            event = { Up = { streak = 1, button = "Left" } },
            mods = "SHIFT",
            action = wezterm.action.OpenLinkAtMouseCursor,
        },
        -- Stop CLICK from opening URLs (it still opens with SHIFT).
        {
            event = { Up = { streak = 1, button = "Left" } },
            mods = "NONE",
            action = wezterm.action.DisableDefaultAssignment,
        },
    }

    config.keys = {
        -- Configuration.
        {
            key = "r",
            mods = "LEADER",
            action = action.ReloadConfiguration,
        },
        -- Enter for new lines in Claude.
        -- SHIFT + Enter to send the prompt in Claude.
        bind_if_else_forward(
            "",
            "Enter",
            process_integration.is_in_claude,
            wezterm.action({ SendString = "\x1b\r" })
        ),
        bind_if_else_forward(
            "SHIFT",
            "Enter",
            process_integration.is_in_claude,
            wezterm.action({ SendString = "\r" })
        ),
        -- Clear screen. When tmux is running, forward to tmux so its own `C-n`
        -- binding handles the `C-l` translation (WezTerm sending `C-l`
        -- directly would trigger tmux's pane navigation instead).
        bind_if_else_forward(
            "CTRL",
            "n",
            process_integration.is_outside_vim_and_tmux,
            action.SendKey({ key = "l", mods = "CTRL" })
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
            "SUPER",
            "c",
            process_integration.is_outside_vim,
            action.CopyTo("Clipboard"),
            action.Nop
        ),
        bind_if_else(
            "SUPER",
            "v",
            process_integration.is_outside_vim,
            action.PasteFrom("Clipboard"),
            action.SendKey({ key = "v", mods = "CTRL|SHIFT" })
        ),
        -- Tabs.
        {
            key = "c",
            mods = "LEADER",
            action = action.SpawnTab("CurrentPaneDomain"),
        },
        {
            key = "h",
            mods = "CTRL|META",
            action = action.ActivateTabRelativeNoWrap(-1),
        },
        {
            key = "l",
            mods = "CTRL|META",
            action = action.ActivateTabRelativeNoWrap(1),
        },
        {
            key = "y",
            mods = "CTRL|META",
            action = action.MoveTabRelative(-1),
        },
        {
            key = "o",
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
                top_level = true,
            }),
        },
        -- Pane navigation. When tmux or nvim is running, always forward so
        -- they handle their own pane navigation (with WezTerm fallback at the
        -- edge).
        bind_if_else_forward(
            "CTRL",
            "h",
            process_integration.is_outside_vim_and_tmux,
            action.ActivatePaneDirection("Left")
        ),
        bind_if_else_forward(
            "CTRL",
            "j",
            process_integration.is_outside_vim_and_tmux,
            action.ActivatePaneDirection("Down")
        ),
        bind_if_else_forward(
            "CTRL",
            "k",
            process_integration.is_outside_vim_and_tmux,
            action.ActivatePaneDirection("Up")
        ),
        bind_if_else_forward(
            "CTRL",
            "l",
            process_integration.is_outside_vim_and_tmux,
            action.ActivatePaneDirection("Right")
        ),
        -- Agent of Empires: new session. When `aoe` is running, intercept `n`
        -- to show a project picker and session name prompt.
        bind_if_else_forward(
            "",
            "n",
            process_integration.is_in_aoe,
            aoe_integration.aoe_new_session_action()
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
