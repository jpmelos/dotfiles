---
description: Review uncommitted changes, changes since a ref, a PR, or files.
argument-hint: '[target] [-- additional instructions]'
disable-model-invocation: true
---

Review the target given at the end of this message.

## Kind of review

Find the kind of review first. Use the first rule that matches the target.

1. If the target is empty, review the uncommitted changes.
2. If the target is a PR URL, a PR number, or a request for a PR, review the
   PR. For example: `https://github.com/org/repo/pull/123`, `123`, `#123`, or
   `PR my-branch`.
3. If the target is a list of paths to files, review the files.
4. If the target is a git ref, review the changes since the ref. A git ref is a
   branch, a tag, a commit, or an expression such as `HEAD~3`. The word "since"
   can come before the ref. If the target is only the word "since", use the
   default branch as the ref. To check that a ref exists, run
   `git rev-list --max-count=1 <ref>`.
5. If the target is a description in plain words, convert it to one of the
   kinds above. For example, "the last two commits" are the changes since
   `HEAD~2`.

If no rule matches the target, ask the user in the chat what to review. Stop
there.

## Uncommitted changes

Obtain the changes first.

- Run `git diff`. Keep the output.
- Run `git diff --cached`. Keep the output.
- Review both outputs together as one change.
- If both outputs are empty, state that there is nothing to review. Stop there.

## Changes since a ref

If the ref is the default branch, find the default branch first. The default
branch is the result of `git main-branch`.

- Run `git main-branch`. If the output names a branch, use it as the default
  branch.
- If that command fails or the output is empty, run `git branch --list` and
  guess the default from the names. Prefer `main` over `master`, and `master`
  over the rest. Names such as `dev` are also common defaults.

Obtain the changes next.

- Run `git diff <ref>...` for the ref in effect. Review that diff.
- Also run `git log <ref>... --oneline` for commit context.
- If both outputs are empty, state that there is nothing to review. Stop there.

## PR

The PR reference can be one of many things. Act accordingly:

- The branch name. Find the PR for this branch in the remote server (GitHub,
  GitLab, etc).
- The PR URL.
- The PR number.

Before you review it, fetch the PR diff and metadata from the remote.

## Files

Obtain the files first. Before you review the files, read each listed file.

## Review

Provide a detailed explanation about what the changes are about, and if you can
figure it out, also explain why the changes would be desirable. In a review of
files, explain instead what the contents of the files are about, and why the
existence of these files is warranted. Feel free to read any files you feel are
necessary to assist you in a more comprehensive review. Think very hard.

If you know that the change, or the work on the files, corresponds to an issue
or a PR in a tracker (GitHub, Linear, etc), read the issue or PR. Also read the
project, the milestones, the parent and related issues and PRs, linked
documents, and any other artifacts attached to it. Use them to understand the
larger context in which the work happens, and review against that context. Look
for the tracker reference in the branch name, the commit messages, the PR title
and description, and the additional instructions.

Review checklist:

- The change or the files are good and bug-free.
- Code is simple and readable.
- Functions and variables are well-named.
- Proper error handling.
- No exposed secrets or API keys.
- Input is validated and sanitized.
- Good test coverage. (Tests can be in other files.)
- Code should have good performance characteristics.

If you fix a problem from the review, always report the fix. If the fix changes
the PR description, present an updated PR description.

If a problem you find is already scheduled to be fixed by future work in the
tracker (a follow-up issue, a later milestone, a later step in the project),
still report it, but tag it as such. Add "\[Scheduled: <reference>\]" after the
item number, where <reference> identifies the issue or milestone that covers
the fix.

If a problem you find existed before the current change and was not introduced
by it, still report it, but tag it as such. Add "[Pre-existent]" after the item
number. Both tags can apply to the same item. Do not use this tag in a review
of files.

Present all findings as review requests. Output comments for the change author.
Do not post comments to a forge. Emit each comment as raw Markdown ready to
copy. The user will paste each comment to the right location in the PR.

Always include all three priority groups. If a group has no findings,
explicitly state so (for example, "There are no critical findings."). Number
feedback items C1..Cn, W1..Wn, S1..Sn:

- Critical issues (must fix).
- Warnings (should fix).
- Suggestions (consider improving).

For each review request:

- Give the exact location first. Name the file path relative to the project
  root. Add the line or line range where the comment belongs. For example, use
  `src/main.rs:45` or `src/lib.rs:23-56`. If the problem is not in the code
  (for example, the problem is in the PR description), mention it.
- Write in plain prose for a human reader. Focus on behavior and functionality.
  State what is wrong, what correct behavior looks like, and why it matters.
  Where relevant, mention architecture, safety, performance, and security
  concerns. Unless a term clarifies the change, avoid function names, variable
  names, layer names, and database terms.
- Keep each comment concise and complete in isolation. Use a few paragraphs.
  Where possible, explain the problem first, then propose a solution.
- Where it helps, include code. Add complete code when reasonable, or partial
  snippets for inspiration.

Except in a review of files, also provide your own version of a PR title and a
PR description.

## Constraints and target

Do not run compilers, linters, or tests.

This message ends with the target. The target can be empty. A "--" separator
can come after the target. If the separator is there, the text after it gives
additional instructions from the user.

If there are additional instructions, follow them. If the additional
instructions conflict with the instructions above, the additional instructions
have priority.

Target to review (additional instructions after "--"):

$ARGUMENTS
