#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND" >&2' ERR

# Navigate tmux panes with WezTerm fallback at the edge.
#
# When tmux is already at the edge (select-pane doesn't change the active
# pane), fall back to WezTerm pane navigation.
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

tmux_at_edge=$(tmux display-message -p "$tmux_at_edge_format")

if [ "$tmux_at_edge" = "1" ]; then
    wezterm cli activate-pane-direction "$wezterm_direction"
else
    tmux select-pane -"$tmux_flag"
fi
