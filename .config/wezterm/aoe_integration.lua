local m = {}

local wezterm = require("wezterm")
local act = wezterm.action

local home = os.getenv("HOME")

local function process_selected_dir_and_session_name(
    prompt_pane,
    selected_dir,
    session_name
)
    if
        not selected_dir
        or selected_dir == ""
        or not session_name
        or session_name == ""
    then
        return
    end

    -- Check if `jpenv-bin/aoe.sh` exists.
    local aoe_sh = selected_dir .. "/jpenv-bin/aoe.sh"
    local exists, _, _ = wezterm.run_child_process({
        "test",
        "-f",
        aoe_sh,
    })

    local base_cmd
    if exists then
        base_cmd = wezterm.shell_quote_arg(aoe_sh)
            .. " "
            .. wezterm.shell_quote_arg(session_name)
    else
        base_cmd = wezterm.shell_quote_arg(home .. "/bin/aid")
            .. " --dir "
            .. wezterm.shell_quote_arg(selected_dir)
            .. " "
            .. wezterm.shell_quote_arg(session_name)
    end

    -- Run in a split pane so output is visible live.
    prompt_pane:split({
        args = {
            "bash",
            "-l",
            "-c",
            base_cmd
                .. ' && { echo ""; echo "Done. Press Enter to close."; read; }'
                .. ' || { rc=$?; echo ""; echo "Command failed (exit $rc). Press Enter to close."; read; }',
        },
        cwd = selected_dir,
        direction = "Bottom",
        size = 0.3,
    })
end

local function process_project_selection(
    inner_window,
    inner_pane,
    selected_dir,
    label
)
    if not selected_dir or selected_dir == "" then
        return
    end

    -- Prompt for session name.
    inner_window:perform_action(
        act.PromptInputLine({
            description = "Enter session name (" .. label .. ")",
            action = wezterm.action_callback(
                function(_, prompt_pane, session_name)
                    process_selected_dir_and_session_name(
                        prompt_pane,
                        selected_dir,
                        session_name
                    )
                end
            ),
        }),
        inner_pane
    )
end

function m.aoe_new_session_action()
    return wezterm.action_callback(function(window, pane)
        -- List project directories.
        local success, stdout, _ =
            wezterm.run_child_process({ home .. "/bin/list_project_dirs" })
        if not success or stdout:match("^%s*$") then
            return
        end

        -- Build choices from output.
        local choices = {}
        for line in stdout:gmatch("[^\n]+") do
            table.insert(choices, {
                id = home .. "/devel/" .. line,
                label = line,
            })
        end

        -- Show directory selector.
        window:perform_action(
            act.InputSelector({
                title = "Select project directory",
                choices = choices,
                fuzzy = true,
                action = wezterm.action_callback(process_project_selection),
            }),
            pane
        )
    end)
end

return m
