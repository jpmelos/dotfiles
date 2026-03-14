-- Custom mux backend that tries tmux pane navigation first, then falls
-- through to WezTerm when at the tmux edge. This enables seamless three-layer
-- navigation: nvim splits -> tmux panes -> WezTerm panes.
local function create_tmux_wezterm_mux()
    local tmux_env = os.getenv("TMUX")
    local tmux_pane = os.getenv("TMUX_PANE")

    local socket = tmux_env:match("^(.-),")

    local tmux_direction = { h = "L", j = "D", k = "U", l = "R", p = "l" }
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

    local mux = {}
    mux.__index = mux

    function mux:zoomed()
        return tmux_exec("display-message -p '#{window_zoomed_flag}'") == "1"
    end

    function mux:navigate(direction)
        local old_pane = tmux_exec("display-message -p '#{pane_id}'")

        tmux_exec(
            string.format(
                "select-pane -t '%s' -%s",
                tmux_pane,
                tmux_direction[direction]
            )
        )

        local new_pane = tmux_exec("display-message -p '#{pane_id}'")

        if old_pane == new_pane then
            -- At the tmux edge. Fall through to WezTerm.
            vim.fn.system(
                string.format(
                    "wezterm cli activate-pane-direction %s",
                    wezterm_direction[direction]
                )
            )
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
