local wezterm = require("wezterm")
local action = wezterm.action
local module = {}

local process_integration = require("process_integration")

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

    config.mouse_bindings = {
        -- Require CTRL+CLICK for opening links.
        {
            event = { Up = { streak = 1, button = "Left" } },
            mods = "CTRL",
            action = wezterm.action.OpenLinkAtMouseCursor,
        },
        -- Stop CLICK from opening URLs (it still opens with CTRL).
        {
            event = { Up = { streak = 1, button = "Left" } },
            mods = "NONE",
            action = wezterm.action.DisableDefaultAssignment,
        },
    }

    config.leader = { key = "s", mods = "CTRL", timeout_milliseconds = 10000 }
    config.keys = {
        -- Configuration.
        {
            key = "r",
            mods = "LEADER",
            action = action.ReloadConfiguration,
        },
        -- TODO: Drop this once we drop Claude.
        --
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
        -- Disable `cmd+c` in Neovim to train muscle memory to use `y` instead.
        bind_if_else(
            "SUPER",
            "c",
            process_integration.is_outside_vim,
            action.CopyTo("Clipboard"),
            action.Nop
        ),
        -- Map `cmd+v` to paste in Neovim.
        bind_if_else(
            "SUPER",
            "v",
            process_integration.is_outside_vim,
            action.PasteFrom("Clipboard"),
            action.SendKey({ key = "v", mods = "CTRL|SHIFT" })
        ),
    }
end

return module
