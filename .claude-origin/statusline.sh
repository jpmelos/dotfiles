#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND" >&2' ERR

# Function to round cost up to the next cent for display.
round_up_cents() {
    local value=$1
    local rounded=$(bc <<< "scale=0; tmp = $value * 100; tmp = tmp / 1; if (tmp < $value * 100) tmp = tmp + 1; scale=2; tmp / 100")
    printf "%.2f" "$rounded"
}

input=$(cat)

MODEL=$(jq -r '.model.display_name' <<< "$input")
COST=$(jq -r '.cost.total_cost_usd' <<< "$input")
USED_PERCENTAGE=$(jq -r '.context_window.used_percentage // 0' <<< "$input")

PROFILE="${AGENT_PROFILE:-unknown}"
PROJECT="${PROJECT_NAME:-}"
BRANCH="$(git branch --show-current 2> /dev/null || true)"
SESSION="${AOE_SESSION_NAME:-}"

status="👤 $PROFILE 📌 $PROJECT"
[ -n "$BRANCH" ] && status="$status 🌿 $BRANCH"
[ -n "$SESSION" ] && status="$status 🎯 $SESSION"
status="$status 🤖 $MODEL 💰 \$$(round_up_cents "$COST") 🪟 $(printf "%.0f" "$USED_PERCENTAGE")% used"
echo "$status"
