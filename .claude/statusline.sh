#!/usr/bin/env bash
set -e

# Function to round cost up to the next cent for display.
round_up_cents() {
    local value=$1
    local rounded=$(echo "scale=0; tmp = $value * 100; tmp = tmp / 1; if (tmp < $value * 100) tmp = tmp + 1; scale=2; tmp / 100" | bc)
    printf "%.2f" "$rounded"
}

input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd')

echo "👤 $MODEL 💰 \$$(round_up_cents "$COST")"
