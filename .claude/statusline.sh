#!/usr/bin/env bash
set -e

input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd')

echo "[$MODEL] 💰 \$$COST"
