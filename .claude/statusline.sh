#!/usr/bin/env bash
set -e

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

echo "👤 $MODEL 💰 \$$(round_up_cents "$COST") 🪟 $(printf "%.0f" "$USED_PERCENTAGE")% used"
