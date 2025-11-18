#!/usr/bin/env bash
set -e
trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND"' ERR

main_branch=$(git main-branch)

diff=$(git diff)
git_command="git diff"
if [ -z "$diff" ]; then
    diff=$(git diff --cached)
    git_command="git diff --cached"
    if [ -z "$diff" ]; then
        diff=$(git diff "$main_branch...")
        git_command="git diff $main_branch..."
        if [ -z "$diff" ]; then
            echo "There is nothing to review."
            exit 1
        fi
    fi
fi

cat << EOF
Review the changes below.

The changes were obtained using: $git_command.

=================

$diff

=================

Provide a detailed explanation on what the change is about, and if you can
figure it out, also explain why the changes would be desirable. Feel free to
read any files you feel is necessary to assist you in a more comprehensive
review. Ultrathink.

Review checklist:

- Change is good and bug-free.
- Code is simple and readable.
- Functions and variables are well-named.
- Proper error handling.
- No exposed secrets or API keys.
- Input is validated and sanitized.
- Good test coverage.
- Code should have good performance characteristics.

Provide feedback organized by priority:

- Critical issues (must fix).
- Warnings (should fix).
- Suggestions (consider improving).

Include specific examples of how to fix issues.

Do not run compilers, linters, or tests.
EOF
