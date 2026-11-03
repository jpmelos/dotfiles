#!/usr/bin/env bash
# Tell the agent which files `jpenv-agents.json` names.
#
# The hook passes the mode as the first argument and the event JSON on
# stdin. Mode `root` combines the `all` and `root` lists from the
# project root. Mode `sibling` expands the `all` list from the
# directory of the file in the event and every parent up to the
# project root. Absent files stay silent. Each load prints a directive
# and a manifest. The agent reads the files with the file tool.

set -u

MODE="${1:-root}"
MARKER_DIR="/tmp/jpenv-agents"
MANIFEST_TAG="jpenv-agents manifest"
DIRECTIVE="Read the listed files with the Read tool"
DIRECTIVE="${DIRECTIVE} when they apply to the task."
DIRECTIVE="${DIRECTIVE} Skip a file whose complete contents"
DIRECTIVE="${DIRECTIVE} are already in context."

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

# Print each directory from the root to the target, one per line.
build_chain() {
  local root="${1%/}" target="${2%/}" stripped current part
  [ -n "$root" ] || {
    printf '%s\n' "$target"
    return
  }
  if [ "$target" = "$root" ]; then
    printf '%s\n' "$root"
    return
  fi
  case "$target" in
    "$root"/*) ;;
    *)
      printf '%s\n' "$target"
      return
      ;;
  esac
  stripped="${target#"$root"/}"
  current="$root"
  printf '%s\n' "$current"
  while [ -n "$stripped" ]; do
    case "$stripped" in
      */*) part="${stripped%%/*}" ;;
      *) part="$stripped" ;;
    esac
    current="$current/$part"
    printf '%s\n' "$current"
    case "$stripped" in
      */*) stripped="${stripped#*/}" ;;
      *) stripped="" ;;
    esac
  done
}

main() {
  local root session key patterns bases base source file dir
  local pattern expansion candidate found matches text count path event
  local all_q root_q
  root="$(resolve_root)"
  [ -n "$root" ] || exit 0
  [ -f "$root/jpenv-agents.json" ] || exit 0

  session="$(json_field '.session_id')"
  [ -n "$session" ] || exit 0
  key="$(sanitize "$session")"
  mkdir -p "$MARKER_DIR"

  # Read the `all` list, with the legacy array as fallback.
  all_q='.context | if type == "array" then .[]? else .all[]? end'
  all_q="$all_q | strings | select(. != \"\")"
  # Read the `root` list, empty for the legacy array shape.
  root_q='.context | if type == "object" then .root[]? else empty end'
  root_q="$root_q | strings | select(. != \"\")"

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
    mapfile -t patterns < <(jq -r "$all_q" \
      "$root/jpenv-agents.json" 2>/dev/null)
    mapfile -t bases < <(jq -r "$root_q" \
      "$root/jpenv-agents.json" 2>/dev/null)
    patterns+=("${bases[@]}")
    bases=("$root")
  else
    mapfile -t patterns < <(jq -r "$all_q" \
      "$root/jpenv-agents.json" 2>/dev/null)
    file="$(json_field '.tool_input.file_path')"
    [ -n "$file" ] || exit 0
    # Resolve a relative path against the project root.
    case "$file" in
      /*) dir="$(dirname "$file")" ;;
      *) dir="$root/$(dirname "$file")" ;;
    esac
    [ -d "$dir" ] || exit 0
    mapfile -t bases < <(build_chain "$root" "$dir")
  fi
  [ "${#patterns[@]}" -gt 0 ] || exit 0
  [ "${#bases[@]}" -gt 0 ] || exit 0

  # Expand each pattern from each base directory into files.
  shopt -s nullglob globstar
  found=()
  for base in "${bases[@]}"; do
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
    event="$(json_field '.hook_event_name')"
    [ -n "$event" ] || event="SessionStart"
    jq -n --arg msg "$text" --arg event "$event" '{
      "systemMessage": $msg,
      "hookSpecificOutput": {
        "hookEventName": $event,
        "additionalContext": $msg
      }
    }'
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
