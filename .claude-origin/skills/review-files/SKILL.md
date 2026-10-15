---
description: Review a file.
argument-hint: file_path1 file_path2 ... [-- additional instructions]
disable-model-invocation: true
---

Review the files listed at the end of this message.

Obtain the files first. Before you review the files, read each listed file.

Provide a detailed explanation about what the contents of the files are about,
and if you can figure it out, also explain why the existence of these files is
warranted. Feel free to read any files you feel are necessary to assist you in
a more comprehensive review. Think very hard.

If you know that the work on these files corresponds to an issue or a PR in a
tracker (GitHub, Linear, etc), read the issue or PR. Also read the project, the
milestones, the parent and related issues and PRs, linked documents, and any
other artifacts attached to it. Use them to understand the larger context in
which the work on these files happens, and review against that context. Look
for the tracker reference in the branch name, the commit messages, the PR title
and description, and the additional instructions.

Review checklist:

- Files are good and bug-free.
- Code is simple and readable.
- Functions and variables are well-named.
- Proper error handling.
- No exposed secrets or API keys.
- Input is validated and sanitized.
- Good test coverage. (Tests may be in other files.)
- Code should have good performance characteristics.

Provide feedback organized by priority. Always include all three sections, even
if a section has no findings — in that case, explicitly state so (for example,
"There are no critical findings."). Feedback items should be numbered C1..Cn,
W1..Wn, S1..Sn:

- Critical issues (must fix).
- Warnings (should fix).
- Suggestions (consider improving).

Include specific examples of how to fix issues.

If a problem you find is already scheduled to be fixed by future work in the
tracker (a follow-up issue, a later milestone, a later step in the project),
still report it, but tag it as such. Add "\[Scheduled: <reference>\]" after the
item number, where <reference> identifies the issue or milestone that covers
the fix.

Do not run compilers, linters, or tests.

This message ends with the list of files to review. A "--" separator can come
after the list. If the separator is there, the text after it gives additional
instructions from the user.

If there are additional instructions, follow them. If the additional
instructions conflict with the instructions above, the additional instructions
have priority.

Files to review (additional instructions after "--"):

$ARGUMENTS
