#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND" >&2' ERR

username="$(whoami)"
devel_dir="$(realpath "$HOME/devel")"
current_dir="$(realpath "$(pwd)")"
project_relative_dir="${current_dir#"$devel_dir"/}"

# Determine profile from directory structure. If the project is nested under a
# directory (e.g., `~/devel/orgname/project`), use the first component as the
# profile. Otherwise, fall back to the current username.
component_count=$(tr '/' '\n' <<< "$project_relative_dir" | wc -l)
if [ "$component_count" -gt 1 ]; then
    profile="$(cut -d'/' -f1 <<< "$project_relative_dir")"
else
    profile="$username"
fi

echo "Pre-run: using profile '$profile'." >&2

# Prepare Claude configuration directory. Copy the base `~/.claude/` to a
# profile-specific location, so each profile gets its own isolated copy.
mkdir -p "$HOME/.claude-$profile"
cp -R "$HOME/.claude/"* "$HOME/.claude-$profile/"
[ -f "$HOME/.claude-$profile.json" ] \
    || echo "{}" > "$HOME/.claude-$profile.json"

# Build the per-container settings.json.
settings=$(cat "$HOME/.claude-$profile/settings.json")

# Fetch secrets from 1Password if not already in environment.
if [ -z "${CLAUDE_CODE_API_KEY:-}" ]; then
    echo "Pre-run: fetching agents configuration from 1Password..." >&2
    if ! SECRETS=$(op read "op://Private/AI Agents Configuration/notesPlain" 2>&1); then
        echo "Error: failed to retrieve configuration from 1Password." >&2
        echo "Make sure you are logged in to 1Password CLI (run: op signin)." >&2
        exit 1
    fi

    fallback_to_username=$(jq -r --arg p "$profile" \
        '.profiles[$p].fallback_to_username // false' <<< "$SECRETS")

    if [[ "$fallback_to_username" == "true" ]]; then
        CLAUDE_CODE_API_KEY=$(jq -r --arg p "$profile" --arg u "$username" \
            '(.profiles[$p].claude_code_api_key // .profiles[$u].claude_code_api_key) // empty' \
            <<< "$SECRETS")
    else
        CLAUDE_CODE_API_KEY=$(jq -r --arg p "$profile" \
            '.profiles[$p].claude_code_api_key // empty' <<< "$SECRETS")
    fi
fi

if [ -z "${GH_TOKEN:-}" ]; then
    echo "Pre-run: fetching GitHub API token from 1Password..." >&2
    if ! GH_TOKEN=$(op read "op://Private/GH Token/notesPlain" 2>&1); then
        echo "Error: failed to retrieve GH_TOKEN from 1Password." >&2
        echo "Make sure you are logged in to 1Password CLI (run: op signin)." >&2
        exit 1
    fi
fi

# Add apiKeyHelper to settings if we have an API key.
if [ -n "${CLAUDE_CODE_API_KEY:-}" ] && [ "$CLAUDE_CODE_API_KEY" != "null" ]; then
    settings=$(jq '. + {"apiKeyHelper": "~/.claude/api-key-helper.sh"}' \
        <<< "$settings")
fi

# Write the final `settings.json` to a temporary file. This file will be
# mounted on top of the directory mount, so each container gets its own
# isolated copy. This is to avoid a problem with Claude Code's status line that
# manifests when you have a `claude` open, and its `settings.json` file is
# overwritten: the status line stops working.
settings_tmp_file=$(mktemp)
printf '%s\n' "$settings" > "$settings_tmp_file"

# Write secrets to a temporary env file to avoid exposing them in the process
# list.
env_file=$(mktemp)
if [ -n "${CLAUDE_CODE_API_KEY:-}" ] && [ "$CLAUDE_CODE_API_KEY" != "null" ]; then
    printf 'CLAUDE_CODE_API_KEY=%s\n' "$CLAUDE_CODE_API_KEY" >> "$env_file"
fi
if [ -n "${GH_TOKEN:-}" ]; then
    printf 'GH_TOKEN=%s\n' "$GH_TOKEN" >> "$env_file"
fi

# Read the current hookable arguments from the file passed as `$1`, append
# extra entries, and output the result as a TOML document with an `args` key.
#
# Uses `toml` (`toml-cli`) to parse the input, so any valid TOML document with
# an `args` key is accepted (single-line, multi-line, etc.). Uses `jq` to merge
# arrays. The output is a JSON-style inline array, which is valid TOML.

input_file="$1"

# Extract the existing args as a JSON array.
existing=$(toml get "$input_file" args)

# Build the extra entries as a JSON array, properly quoting all values.
extra=$(
    jq -n \
        --arg a1 "--volume" --arg v1 "$settings_tmp_file:$HOME/.claude/settings.json" \
        --arg a2 "--env-file" --arg v2 "$env_file" \
        --arg a3 "--env" --arg v3 "AGENT_PROFILE=$profile" \
        '[$a1, $v1, $a2, $v2, $a3, $v3]'
)

# Merge the existing and extra arrays into a TOML document.
merged=$(jq -cn --argjson existing "$existing" --argjson extra "$extra" \
    '$existing + $extra')
echo "args = ${merged}"
