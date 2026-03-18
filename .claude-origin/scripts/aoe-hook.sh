#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND" >&2' ERR

[ -n "${AOE_INSTANCE_ID:-}" ] || exit 0
mkdir -p "/tmp/aoe-hooks/$AOE_INSTANCE_ID"
echo "$1" > "/tmp/aoe-hooks/$AOE_INSTANCE_ID/status"
