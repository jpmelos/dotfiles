#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND"' ERR
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# We only need this because the default hook found in
# https://github.com/pre-commit/pre-commit-hooks on version 6.0.0 with id
# `check-executables-have-shebangs` does not run reliably in Docker containers:
# sometimes it reports non-executable files as executable files missing the
# shebang. We traced it back to Python's `os.access(path, os.X_OK)`
# returning `True` for non-executables files, and we don't know whether that's
# a bug or not. That makes the `identify` library report files that are not
# executable as such. Thus, `pre-commit` passes non-executable files to its
# script, and the script returns errors (it doesn't check again whether those
# files are executable, it just trusts `identify`).

# Detect OS to use the correct `stat` format.
if [[ "$OSTYPE" == "darwin"* ]]; then
    STAT_FORMAT="-f %Lp"
else
    STAT_FORMAT="-c %a"
fi

if [ $# -eq 0 ]; then
    while IFS= read -r -d '' file; do
        set -- "$@" "$file"
    done < <(find . -type f -executable -print0)
fi

failed=0
for file in "$@"; do
    if [ ! -f "$file" ]; then
        continue
    fi

    # Check if file is actually executable by examining the permission bits. We
    # use `stat` to get the octal permissions and check if any execute bit is
    # set.
    perms=$(stat "$STAT_FORMAT" "$file" 2> /dev/null || echo "000")
    owner_exec=$((perms / 100 % 10))
    group_exec=$((perms / 10 % 10))
    other_exec=$((perms % 10))

    # Check if any execute bit is set (odd number means execute bit is set).
    if [ $((owner_exec % 2)) -eq 1 ] \
        || [ $((group_exec % 2)) -eq 1 ] \
        || [ $((other_exec % 2)) -eq 1 ]; then
        if ! head -n 1 "$file" | grep -q '^#!'; then
            echo -n "Error: Executable file $file "
            echo "does not start with a shebang (#!)."
            failed=1
        fi
    fi
done

exit $failed
