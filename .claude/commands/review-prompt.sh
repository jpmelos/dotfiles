#!/usr/bin/env bash
set -e
trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND"' ERR

main_branch=$(git main-branch)
diff=$(git diff "$main_branch...")

if [ -z "$diff" ]; then
    echo "There is nothing to review."
    exit 1
fi

cat << EOF
Changes to review:

=================

$diff

=================

Do not run compilers, linters, or tests.

Ultrathink.

Review checklist:

- Change is good and bug-free.
- Code is simple and readable.
- Functions and variables are well-named.
- Proper error handling.
- No exposed secrets or API keys.
- Input is validated.
- Good test coverage.
- Code should have good performance characteristics.

Summarize what the change is about, and provide feedback organized by priority:

- Critical issues (must fix).
- Warnings (should fix).
- Suggestions (consider improving).

Include specific examples of how to fix issues.
EOF
