#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND" >&2' ERR
cd "$(dirname "${BASH_SOURCE[0]}")/.."

CHAR_LIMIT=79

if [ $# -eq 0 ]; then
    while IFS= read -r -d '' file; do
        set -- "$@" "$file"
    done < <(find . -name "*.py" -print0)
fi

errors=0

for file in "$@"; do
    line_number=0
    while IFS= read -r line; do
        line_number=$((line_number + 1))
        length=${#line}
        if [ "$length" -gt "$CHAR_LIMIT" ]; then
            echo -n "Error: $file:$line_number has $length characters, "
            echo "exceeding the $CHAR_LIMIT character limit."
            errors=$((errors + 1))
        fi
    done < "$file"
done

if [ "$errors" -gt 0 ]; then
    exit 1
fi
