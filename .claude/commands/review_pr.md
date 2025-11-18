---
description: Review a PR
argument-hint: [pr_number]
---

Review PR $1. Use the `gh` command to fetch PR details.

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
