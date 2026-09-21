#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND" >&2' ERR

# The `ai` launcher sets `AGENT_PROFILE` in every container that it starts.
# Inside one, use the pager that Git uses when `core.pager` is not set: the
# `PAGER` variable, or `less`. Git runs the pager through a shell, so `PAGER`
# can hold arguments, and `sh -c` keeps that behavior.
if [ -n "${AGENT_PROFILE:-}" ]; then
    exec sh -c "${PAGER:-less}"
fi
# 174 = 80 columns for each version, 6 for each gutter, 2 for spacing
if [ "$(tput cols)" -gt 174 ]; then
    exec delta --side-by-side
fi
exec delta
