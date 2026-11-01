#!/usr/bin/env bash
# Tell the agent which files `jpenv-agents.json` names.
#
# The hook passes the mode as the first argument and the event JSON on
# stdin. Mode `root` resolves patterns from the project root. Mode
# `sibling` resolves the same patterns from the directory of the file in
# the event. Absent files stay silent. Each load prints a directive and
# a manifest. The agent reads the files with the file tool.

set -u

MODE="${1:-root}"
MARKER_DIR="/tmp/jpenv-agents"
MANIFEST_TAG="jpenv-agents manifest"
DIRECTIVE="Read each listed file in full with the file tool. "
DIRECTIVE="${DIRECTIVE}Skip a file whose complete contents "
DIRECTIVE="${DIRECTIVE}are already in context."

INPUT="$(cat)"

# Print one string field from the event JSON, or nothing.
json_field() {
  printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null
}

# Print the project root for the event.
resolve_root() {
  if [ -n "${CLAUDE_PROJECT_DIR:-}" ]; then
    printf '%s' "$CLAUDE_PROJECT_DIR"
  else
    json_field '.cwd'
  fi
}

# Print the value with safe characters.
sanitize() {
  printf '%s' "$1" | tr -C 'A-Za-z0-9_.-' '_'
}

# Append one path to the loaded list for the session key.
record_loaded() {
  printf '%s\n' "$2" >> "$MARKER_DIR/$1.loaded"
}

# Return zero when the path is already in the loaded list.
is_loaded() {
  [ -f "$MARKER_DIR/$1.loaded" ] && grep -Fxq "$2" "$MARKER_DIR/$1.loaded"
}

main() {
  local root session key patterns base source file dir
  local pattern expansion candidate found matches text count path
  root="$(resolve_root)"
  [ -n "$root" ] || exit 0
  [ -f "$root/jpenv-agents.json" ] || exit 0

  session="$(json_field '.session_id')"
  [ -n "$session" ] || exit 0
  key="$(sanitize "$session")"
  mkdir -p "$MARKER_DIR"

  # Read the pattern list for this run.
  mapfile -t patterns < <(jq -r '.context[]? | strings | select(. != "")' \
    "$root/jpenv-agents.json" 2>/dev/null)
  [ "${#patterns[@]}" -gt 0 ] || exit 0

  if [ "$MODE" = "root" ]; then
    source="$(json_field '.source')"
    # Startup and clear sources load. Resume, fork, and compact never load.
    case "$source" in
      ""|startup|clear) ;;
      *) exit 0 ;;
    esac
    # Drop the guard on clear.
    if [ "$source" = "clear" ]; then
      rm -rf "$MARKER_DIR/$key" "$MARKER_DIR/$key.loaded"
    fi
    # The session loads once. Later runs see the guard and stop.
    [ -e "$MARKER_DIR/$key" ] && exit 0
    base="$root"
  else
    file="$(json_field '.tool_input.file_path')"
    [ -n "$file" ] || exit 0
    # Resolve a relative path against the project root.
    case "$file" in
      /*) dir="$(dirname "$file")" ;;
      *) dir="$root/$(dirname "$file")" ;;
    esac
    [ -d "$dir" ] || exit 0
    base="$dir"
  fi

  # Expand each pattern from the base directory into files.
  shopt -s nullglob globstar
  found=()
  for pattern in "${patterns[@]}"; do
    if [[ "$pattern" == /* ]]; then
      expansion="$pattern"
    else
      expansion="$base/$pattern"
    fi
    while IFS= read -r candidate; do
      [ -f "$candidate" ] || continue
      is_loaded "$key" "$candidate" && continue
      found+=("$candidate")
    done < <(compgen -G "$expansion")
  done
  [ "${#found[@]}" -gt 0 ] || exit 0

  # Sort the matches for stable output.
  matches=()
  mapfile -t matches < <(printf '%s\n' "${found[@]}" | LC_ALL=C sort -u)

  # Build the directive and the manifest.
  count="${#matches[@]}"
  text="$DIRECTIVE
$MANIFEST_TAG ($count files):"
  for path in "${matches[@]}"; do
    text="$text
- $path"
    record_loaded "$key" "$path"
  done

  if [ "$MODE" = "root" ]; then
    touch "$MARKER_DIR/$key"
    printf '%s\n' "$text"
  else
    jq -n --arg ctx "$text" '{
      "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "additionalContext": $ctx
      }
    }'
  fi
}

main
