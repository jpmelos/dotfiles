Review the current changes. Current changes are defined as below:

Find out whether you are in the main branch, or a different branch. Run
`git main-branch` to find out what the main branch is. If you are in the main
branch, consider current all the changes that haven't been committed yet
(staged and otherwise). If you are not in the main branch, consider current all
the differences from the main branch (committed, staged, and otherwise).

Do not run compilers, linters, or tests.

Review checklist:

- Change is good and bug-free.
- Code is simple and readable.
- Functions and variables are well-named.
- Proper error handling.
- No exposed secrets or API keys.
- Input is validated.
- Good test coverage.
- Performance considerations addressed.

Provide feedback organized by priority:

- Critical issues (must fix).
- Warnings (should fix).
- Suggestions (consider improving).

Include specific examples of how to fix issues.
