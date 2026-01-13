---
description: Review a PR.
---

Review PR $1.

$1 could be one of many things, act accordingly:

- The branch name.
  - Find the PR for this branch in the remote server (GitHub, GitLab, etc).
- The PR URL.
- The PR number.

Provide a detailed explanation about what the changes are about, and if you can
figure it out, also explain why the changes would be desirable. Feel free to
read any files you feel is necessary to assist you in a more comprehensive
review. Think very hard.

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
