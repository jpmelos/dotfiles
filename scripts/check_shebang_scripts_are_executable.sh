#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND"' ERR
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# The default hook found in https://github.com/pre-commit/pre-commit-hooks on
# version 6.0.0 with id `check-shebang-scripts-are-executable` does not run
# reliably in Docker containers, so we created an alternative in
# `scripts/check_executables_have_shebangs.sh`. Then we decided to follow with
# this one since it's an obvious companion.

# Detect OS to use the correct `stat` format.
if [[ "$OSTYPE" == "darwin"* ]]; then
    STAT_FORMAT="-f %Lp"
else
    STAT_FORMAT="-c %a"
fi

if [ $# -eq 0 ]; then
    while IFS= read -r -d '' file; do
        set -- "$@" "$file"
    done < <(find . -type f -print0)
fi

failed=0
for file in "$@"; do
    if [ ! -f "$file" ]; then
        continue
    fi

    # Check if file starts with a shebang.
    if head -n 1 "$file" 2> /dev/null | grep -q '^#!'; then
        # Check if user execute bit is set by examining the permission bits. We
        # use `stat` to get the octal permissions and check the owner execute
        # bit.
        perms=$(stat "$STAT_FORMAT" "$file" 2> /dev/null || echo "000")
        owner_exec=$((perms / 100 % 10))

        # Check if owner execute bit is set (odd number means execute bit is
        # set).
        if [ $((owner_exec % 2)) -eq 0 ]; then
            echo "Error: Shebang script $file is not executable for the user."
            failed=1
        fi
    fi
done

exit $failed
