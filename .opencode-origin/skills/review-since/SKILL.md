---
name: review-since
description: Review changes since a ref.
metadata:
  opencode/autoinvoke: false
---

Review everything that changed since the given ref.

The ref appears at the end of this message. A "--" separator can come after the
ref. If the separator is there, the text after it gives additional instructions
from the user. If the ref is empty or missing, use the default branch.

Find the default branch first. The default branch is the result of
`git main-branch`.

- Run `git main-branch`. If the output names a branch, use it as the default
  branch.
- If that command fails or the output is empty, run `git branch --list` and
  guess the default from the names. Prefer `main` over `master`, and `master`
  over the rest. Names such as `dev` are also common defaults.

Obtain the changes next.

- Run `git diff <ref>...` for the ref in effect. Review that diff.
- Also run `git log <ref>... --oneline` for commit context.
- If both outputs are empty, state that there is nothing to review. Stop there.

Provide a detailed explanation about what the changes are about, and if you can
figure it out, also explain why the changes would be desirable. Feel free to
read any files you feel are necessary to assist you in a more comprehensive
review. Think very hard.

If you know that the change corresponds to an issue or a PR in a tracker
(GitHub, Linear, etc), read the issue or PR. Also read the project, the
milestones, the parent and related issues and PRs, linked documents, and any
other artifacts attached to it. Use them to understand the larger context in
which the change happens, and review against that context. Look for the tracker
reference in the branch name, the commit messages, the PR title and
description, and the additional instructions.

Finally, provide your own version of:

- A PR title, at most 50 characters.
- A PR description that is concise and to the point, without excluding any
  important topics that need to be covered.

Emit the title and the description as raw Markdown, ready to paste into GitHub.
Put the title alone inside its own fenced code block. Put the description
inside a separate fenced code block, with the fence tagged as "markdown", so
that the raw Markdown syntax (headings, lists, links, inline code) is visible
and can be copied verbatim. Do not render the description as formatted Markdown
outside the code block. If the description contains code blocks of its own, use
a fence of four backticks for the outer block.

Review checklist:

- Change is good and bug-free.
- Code is simple and readable.
- Functions and variables are well-named.
- Proper error handling.
- No exposed secrets or API keys.
- Input is validated and sanitized.
- Good test coverage.
- Code should have good performance characteristics.

Provide feedback organized by priority. Always include all three sections, even
if a section has no findings — in that case, explicitly state so (for example,
"There are no critical findings."). Feedback items should be numbered C1..Cn,
W1..Wn, S1..Sn:

- Critical issues (must fix).
- Warnings (should fix).
- Suggestions (consider improving).

Include specific examples of how to fix issues.

If you fix a problem from the review, always report the fix. If the fix changes
the PR description, present an updated PR description.

If a problem you find is already scheduled to be fixed by future work in the
tracker (a follow-up issue, a later milestone, a later step in the project),
still report it, but tag it as such. Add "\[Scheduled: <reference>\]" after the
item number, where <reference> identifies the issue or milestone that covers
the fix.

Do not run compilers, linters, or tests.

This message ends with the ref. A "--" separator can come after the ref. If the
separator is there, the text after it gives additional instructions from the
user.

If there are additional instructions, follow them. If the additional
instructions conflict with the instructions above, the additional instructions
have priority.

Ref to review since (additional instructions after "--" appear in the user
message after this skill block).
