#!/usr/bin/env bash
set -e

query=$(cat | jq -r '.query')

rg --files "$CLAUDE_PROJECT_DIR" \
    | fzf --filter "$query" \
    | head -15
