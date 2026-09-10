#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND" >&2' ERR

if [ "$(tput cols)" -gt 160 ]; then
    delta --side-by-side
else
    delta
fi
