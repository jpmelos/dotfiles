#!/usr/bin/env bash
set -e

query=$(cat | jq -r '.query')
rg --files | fzf --filter "$query" | head -15
