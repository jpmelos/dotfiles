#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND" >&2' ERR

# Navigate tmux panes with WezTerm fallback at the edge.
#
# tmux `select-pane` wraps around at the edge of the window. To prevent the
# wrap, check the edge before the move. If the active tmux pane is at the edge,
# fall back to WezTerm pane navigation instead.
#
# If the active tmux pane is in a mode, for example copy mode, do nothing.
#
# Usage: pane-navigate.sh <direction>
#   direction: left, down, up, or right.

direction="$1"

case "$direction" in
    left)
        tmux_flag="L"
        tmux_at_edge_format="#{pane_at_left}"
        wezterm_direction="Left"
        ;;
    down)
        tmux_flag="D"
        tmux_at_edge_format="#{pane_at_bottom}"
        wezterm_direction="Down"
        ;;
    up)
        tmux_flag="U"
        tmux_at_edge_format="#{pane_at_top}"
        wezterm_direction="Up"
        ;;
    right)
        tmux_flag="R"
        tmux_at_edge_format="#{pane_at_right}"
        wezterm_direction="Right"
        ;;
    *)
        echo "Unknown direction: $direction" >&2
        exit 1
        ;;
esac

# In a mode, tmux looks up a key in the root key table if the key table of the
# mode does not bind it. So this script can run while the pane is in a mode.
pane_in_mode=$(tmux display-message -p "#{pane_in_mode}")
if [ "$pane_in_mode" = "1" ]; then
    exit 0
fi

tmux_at_edge=$(tmux display-message -p "$tmux_at_edge_format")

if [ "$tmux_at_edge" = "1" ]; then
    # Inside tmux, `WEZTERM_PANE` and `WEZTERM_UNIX_SOCKET` keep the values
    # from the shell that started the tmux server. These values can point to a
    # closed pane, a pane in another tab, or an old WezTerm process. Without
    # them, `wezterm cli` finds the running WezTerm process and uses its
    # focused pane. With `--no-auto-start`, `wezterm cli` does not start a mux
    # server if no WezTerm process runs.
    env -u WEZTERM_PANE -u WEZTERM_UNIX_SOCKET \
        wezterm cli --no-auto-start \
        activate-pane-direction "$wezterm_direction"
else
    tmux select-pane -"$tmux_flag"
fi
