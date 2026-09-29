-- Custom mux backend that tries tmux pane navigation first, then falls
-- through to WezTerm when at the tmux edge. This enables seamless three-layer
-- navigation: nvim splits -> tmux panes -> WezTerm panes.
local function create_tmux_wezterm_mux()
    local tmux_env = os.getenv("TMUX")
    local tmux_pane = os.getenv("TMUX_PANE")

    local socket = tmux_env:match("^(.-),")

    local tmux_direction = { h = "L", j = "D", k = "U", l = "R", p = "l" }
    local tmux_at_edge_format = {
        h = "#{pane_at_left}",
        j = "#{pane_at_bottom}",
        k = "#{pane_at_top}",
        l = "#{pane_at_right}",
    }
    local wezterm_direction = {
        h = "Left",
        j = "Down",
        k = "Up",
        l = "Right",
        p = "Prev",
    }

    local function tmux_exec(args)
        return vim.fn
            .system(string.format("tmux -S %s %s", socket, args))
            :gsub("%s+$", "")
    end

    -- Expand a tmux format for the tmux pane of this Nvim instance.
    local function tmux_pane_format(format)
        return tmux_exec(
            string.format(
                "display-message -p -t '%s' '%s'",
                tmux_pane,
                format
            )
        )
    end

    local function tmux_select_pane(direction)
        tmux_exec(
            string.format(
                "select-pane -t '%s' -%s",
                tmux_pane,
                tmux_direction[direction]
            )
        )
    end

    local mux = {}
    mux.__index = mux

    function mux:zoomed()
        return tmux_exec("display-message -p '#{window_zoomed_flag}'") == "1"
    end

    function mux:navigate(direction)
        local at_edge
        if direction == "p" then
            -- `select-pane -l` does nothing when the window has no last pane.
            -- The pane of this Nvim instance then stays active.
            tmux_select_pane(direction)
            at_edge = tmux_pane_format("#{pane_active}") == "1"
        else
            -- `select-pane` wraps around at the edge of the window. Check
            -- the edge before the move to prevent the wrap.
            at_edge = tmux_pane_format(tmux_at_edge_format[direction]) == "1"
            if not at_edge then
                tmux_select_pane(direction)
            end
        end

        if at_edge then
            -- At the tmux edge. Fall through to WezTerm.
            --
            -- Inside tmux, `WEZTERM_PANE` and `WEZTERM_UNIX_SOCKET` keep the
            -- values from the shell that started the tmux server. These
            -- values can point to a closed pane, a pane in another tab, or an
            -- old WezTerm process. Without them, `wezterm cli` finds the
            -- running WezTerm process and uses its focused pane. With
            -- `--no-auto-start`, `wezterm cli` does not start a mux server if
            -- no WezTerm process runs.
            vim.fn.system({
                "env",
                "-u",
                "WEZTERM_PANE",
                "-u",
                "WEZTERM_UNIX_SOCKET",
                "wezterm",
                "cli",
                "--no-auto-start",
                "activate-pane-direction",
                wezterm_direction[direction],
            })
        end
    end

    return setmetatable({}, mux)
end

return {
    "numToStr/Navigator.nvim",
    keys = {
        { "<C-h>", "<cmd>NavigatorLeft<cr>", mode = "n" },
        { "<C-l>", "<cmd>NavigatorRight<cr>", mode = "n" },
        { "<C-k>", "<cmd>NavigatorUp<cr>", mode = "n" },
        { "<C-j>", "<cmd>NavigatorDown<cr>", mode = "n" },
    },
    config = function()
        local in_tmux = os.getenv("TMUX") and os.getenv("TMUX_PANE")

        if in_tmux then
            -- Inside tmux: use custom mux that tries tmux pane navigation
            -- first, then falls through to WezTerm at the edge.
            require("Navigator").setup({
                mux = create_tmux_wezterm_mux(),
            })
        else
            require("Navigator").setup()
        end
    end,
}
