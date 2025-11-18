#!/usr/bin/env bash
set -e
trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND"' ERR

diff=$(git diff)
git_command="git diff"
if [ -z "$diff" ]; then
    diff=$(git diff --cached)
    git_command="git diff --cached"
    if [ -z "$diff" ]; then
        main_branch=$(git main-branch)
        diff=$(git diff "$main_branch...")
        git_command="git diff $main_branch..."
        if [ -z "$diff" ]; then
            echo "There is nothing to review."
            exit 1
        fi
    fi
fi

cat << EOF
The changes were obtained using: $git_command.

=================

$diff

=================
EOF
