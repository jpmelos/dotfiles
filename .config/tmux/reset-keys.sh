#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND" >&2' ERR

# Reset every key binding in the running tmux server to the tmux defaults.
#
# tmux has no command for this. A binding that a configuration file removed or
# changed stays that way until the server restarts, so `source-file` alone does
# not bring the defaults back. This script starts a second tmux server with no
# configuration, copies its bindings, removes every key table from the running
# server, and loads the copied bindings into it.
#
# Usage: reset-keys.sh
#   Run it from `run-shell` in the tmux configuration, before the first
#   `bind-key`. `run-shell` sets `TMUX`, which points the `tmux` commands below
#   at the running server.

if [ -z "${TMUX:-}" ]; then
    echo "TMUX is not set. Run this script from tmux." >&2
    exit 1
fi

# Socket name of the throwaway server. The PID keeps concurrent runs apart.
defaults_socket="reset-keys-$$"

# One complete `bind-key` command per binding. The repeat flag and the key note
# are kept. `q|a` quotes the key string as a tmux argument. Default key notes
# contain no double quotes.
bind_format='bind-key #{?key_repeat,-r ,}#{?key_note,-N "#{key_note}" ,}-T #{key_table} #{q|a:key_string} #{key_command}'

# Read the defaults before the running server loses anything. If this fails,
# for example because the installed tmux does not support `list-keys -F`, the
# script exits here and the running server keeps its bindings.
defaults="$(tmux -L "$defaults_socket" -f /dev/null start-server \; list-keys -F "$bind_format")"
tmux -L "$defaults_socket" kill-server 2> /dev/null || true

if [ -z "$defaults" ]; then
    echo "The throwaway tmux server returned no key bindings." >&2
    exit 1
fi

# `unbind-key -a -T` removes the whole table. This also removes tables that
# plugins created.
tmux list-keys -F '#{key_table}' | sort -u | while read -r key_table; do
    tmux unbind-key -a -T "$key_table"
done

printf '%s\n' "$defaults" | tmux source-file -
