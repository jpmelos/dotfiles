#!/usr/bin/env bash
set -uo pipefail

# This hook names the session from the full transcript.
# A nested run exports `AUTO_TITLE_NESTED`, so the inner prompt skips this hook.
# Any failure exits with success and no title. The prompt still runs.

if [ -n "${AUTO_TITLE_NESTED:-}" ]; then
  exit 0
fi

input=$(cat)
prompt=$(jq -r '.prompt // empty' <<< "$input")
transcript_path=$(jq -r '.transcript_path // empty' <<< "$input")

# An empty prompt carries no name. Stay silent here.
if [ -z "$prompt" ]; then
  exit 0
fi

history_text=""
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
  history_text=$(jq -r 'select(.type == "user" or .type == "assistant") | .message.content? // empty | if type == "array" then .[] | select(type == "object" and .type == "text") | .text? // empty elif type == "string" then . else empty end' "$transcript_path" 2> /dev/null || true)
fi

combined="$history_text
---
$prompt"

# Bound the request so a long session still answers inside the hook timeout.
if [ "${#combined}" -gt 24000 ]; then
  combined=$(tail -c 24000 <<< "$combined")
fi

instructions="Write a short session title in lowercase kebab-case, 3 to 6 words and at most 50 characters, that describes the whole session below. Reply with the title only and no quotes."

export AUTO_TITLE_NESTED=1
raw_title=$(claude -p --model haiku --max-turns 1 --output-format text "$instructions

$combined" 2> /dev/null || true)

title=$(printf '%s' "$raw_title" | head -n 1 | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | tr -s '-' | sed 's/^-//;s/-$//' | cut -c1-50 | sed 's/-$//')

# No usable title. Stay silent and keep the current name.
if [ -z "$title" ]; then
  exit 0
fi

jq -n --arg title "$title" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", sessionTitle: $title}}'
exit 0
