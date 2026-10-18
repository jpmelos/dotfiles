#!/usr/bin/env bash
set -uo pipefail

# This hook names the session after each assistant response.
# The foreground step only starts a background worker and exits at once.
# The worker reads the full transcript with Haiku and appends the new title.
# Any failure stays silent. The session continues as normal.

# A nested generation run skips this hook outright.
if [ -n "${AUTO_TITLE_NESTED:-}" ]; then
  exit 0
fi

# A detached worker performs the slow title request.
if [ -n "${AUTO_TITLE_WORKER:-}" ]; then
  sleep 5
  history_text=$(jq -r 'if .type == "summary" then .summary? // empty elif .type == "user" or .type == "assistant" then .message.content? // empty | if type == "array" then .[] | select(type == "object" and .type == "text") | .text? // empty elif type == "string" then . else empty end else empty end' "$AUTO_TITLE_TRANSCRIPT" 2> /dev/null || true)
  # An empty history carries no name.
  if [ -z "$history_text" ]; then
    exit 0
  fi
  combined="$history_text"
  instructions="Write a short session title in lowercase kebab-case, 3 to 6 words and at most 50 characters, that describes the whole session below. Reply with the title only and no quotes."
  raw_title=$(claude -p --model haiku --max-turns 1 --output-format text "$instructions

$combined" 2> /dev/null || true)
  title=$(printf '%s' "$raw_title" | head -n 1 | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | tr -s '-' | sed 's/^-//;s/-$//' | cut -c1-50 | sed 's/-$//')
  # Without a usable title the script keeps the current name.
  if [ -z "$title" ]; then
    exit 0
  fi
  last_title=$(grep -F '"custom-title"' "$AUTO_TITLE_TRANSCRIPT" 2> /dev/null | tail -n 1 | jq -r '.customTitle // empty' 2> /dev/null || true)
  # The name is current, so the worker writes nothing.
  if [ "$title" = "$last_title" ]; then
    exit 0
  fi
  line=$(jq -n -c --arg title "$title" --arg session "$AUTO_TITLE_SESSION_ID" '{type: "custom-title", customTitle: $title, sessionId: $session}' 2> /dev/null || true)
  if [ -n "$line" ]; then
    printf '%s\n' "$line" >> "$AUTO_TITLE_TRANSCRIPT"
  fi
  exit 0
fi

input=$(cat)
session_id=$(jq -r '.session_id // empty' <<< "$input")
transcript_path=$(jq -r '.transcript_path // empty' <<< "$input")

# Without a session or a transcript there is nothing to name.
if [ -z "$session_id" ] || [ -z "$transcript_path" ]; then
  exit 0
fi

export AUTO_TITLE_NESTED=1
export AUTO_TITLE_WORKER=1
export AUTO_TITLE_SESSION_ID="$session_id"
export AUTO_TITLE_TRANSCRIPT="$transcript_path"
nohup bash "$0" < /dev/null > /dev/null 2>&1 &
exit 0
