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

echo "$input" > /tmp/claude-code-shared/statuslineinput.json

MODEL=$(jq -r '.model.display_name' <<< "$input")
COST=$(jq -r '.cost.total_cost_usd' <<< "$input")
USED_PERCENTAGE=$(jq -r '.context_window.used_percentage // 0' <<< "$input")

# Rate limits: extract percentage and reset time if available.
FIVE_H_PCT=$(jq -r '.rate_limits.five_hour.used_percentage // empty' <<< "$input")
FIVE_H_RESET=$(jq -r '.rate_limits.five_hour.resets_at // empty' <<< "$input")
SEVEN_D_PCT=$(jq -r '.rate_limits.seven_day.used_percentage // empty' <<< "$input")
SEVEN_D_RESET=$(jq -r '.rate_limits.seven_day.resets_at // empty' <<< "$input")

# Format time remaining until reset as human-readable string.
format_remaining() {
    local resets_at=$1

    local now
    now=$(date +%s)

    local diff=$((resets_at - now))
    if ((diff <= 0)); then
        echo "now"
        return
    fi

    local days=$((diff / 86400))
    local hours=$(((diff % 86400) / 3600))
    local minutes=$(((diff % 3600) / 60))
    if ((days > 0)); then
        echo "${days}d ${hours}h ${minutes}m"
    elif ((hours > 0)); then
        echo "${hours}h ${minutes}m"
    else
        echo "${minutes}m"
    fi
}

LIMITS=""
if [ -n "$FIVE_H_PCT" ]; then
    LIMITS="5h: $(printf '%.0f' "$FIVE_H_PCT")%"
    [ -n "$FIVE_H_RESET" ] && LIMITS="$LIMITS ($(format_remaining "$FIVE_H_RESET"))"
fi
if [ -n "$SEVEN_D_PCT" ]; then
    [ -n "$LIMITS" ] && LIMITS="$LIMITS "
    LIMITS="${LIMITS}7d: $(printf '%.0f' "$SEVEN_D_PCT")%"
    [ -n "$SEVEN_D_RESET" ] && LIMITS="$LIMITS ($(format_remaining "$SEVEN_D_RESET"))"
fi

PROFILE="${AGENT_PROFILE:-unknown}"
PROJECT="${PROJECT_NAME:-}"
BRANCH="$(git branch --show-current 2> /dev/null || true)"
SESSION="${AOE_SESSION_NAME:-}"

first_line="👤 $PROFILE 📌 $PROJECT"
[ -n "$BRANCH" ] && first_line="$first_line 🌿 $BRANCH"
[ -n "$SESSION" ] && first_line="$first_line 🎯 $SESSION"
echo "$first_line"

second_line="🤖 $MODEL 💰 \$$(round_up_cents "$COST") 🪟 $(printf "%.0f" "$USED_PERCENTAGE")% used"
[ -n "$LIMITS" ] && second_line="$second_line 📊 $LIMITS"
echo "$second_line"
