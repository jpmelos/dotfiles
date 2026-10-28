---
description: Determine the next action from a tracker reference.
argument-hint: tracker_reference [-- additional instructions]
disable-model-invocation: true
---

Determine the next action from the tracker reference at the end of this
message.

The reference can be one of many things. Act accordingly:

- A project URL or identifier.
- A list URL or identifier. A list is a container that holds items. Examples
  are a Trello list, a project column, or a saved tracker view.
- An issue URL or identifier.
- A pull request URL or identifier.
- A branch name linked to a pull request.

If the reference is empty, run `ai_default_next` to get the default reference.
Use the output as the reference. If the reference is still empty or ambiguous,
stop. Ask the user which object to use. Ask directly in the chat. Do not use a
tool to ask.

## 1. Read the referenced object

Read the full object with available tracker tools. Do not guess content.

- For an issue, read title, description, status, assignee, labels, project,
  milestone, parent, relations, links, and comments.
- For a project, read title, description, goals, and all items with title,
  status, assignee, and milestone. Page through all results.
- For a list, read title, parent board or parent project, and all items. Page
  through all results.
- For each item, read title, description or body, status, assignee, and
  milestone.
- For a pull request, read title, description, state, diff, checks, reviews,
  review threads, comments, and linked issues.
- If the object does not exist or access fails, report that fact and stop.

## 2. Always expand sub-issues and links

This step is mandatory for every issue. Complete it even when the parent looks
complete.

- List direct sub-issues with identifier, title, status, and assignee.
- Recurse into each open sub-issue and list its sub-issues.
- Read the parent issue, blockers, blocked issues, related issues, and linked
  pull requests.
- For a pull request, also read each linked issue and its sub-issues.
- For a project, expand sub-issues for each open issue.
- For a list, expand sub-issues for each item. Treat each item as an issue.
- For a list, follow links from each item description or body. Read each linked
  issue or linked pull request with its sub-issues.
- Page through all results. Do not stop at the first page.

## 3. Determine next actions

Check status, blockers, assignees, comments, reviews, checks, and milestones.
Apply these rules:

- Prefer open and unblocked work over blocked work.
- Prefer active work with recent comments or reviews over idle work.
- Flag pull requests with failed checks or open review threads.
- Flag issues with no assignee or with stale discussion.
- If the reference is not a list, order candidates from most urgent to least
  urgent.
- If the reference is a list, determine next actions for each item separately.
- If the reference is a list, do not merge actions across items into one global
  order.
- If the reference is a list, order items as they appear in the list.
- If the reference is a list, order actions within each item from most urgent
  to least urgent.

## 4. Output

If the reference is not a list, present a short summary of the current state.
If the reference is not a list, present an ordered list of next actions. For
each action, give identifier and title, reason it ranks there, blockers if any,
and a concrete entry point.

If the reference is a list, present a short summary of the list state. Then
present one section for each item in list order. For each item, give identifier
and title. Then give its ordered next actions with reason, blockers, and entry
point. If an item has no further action, state that fact under the item.

- For each action that includes development work:
  - State the repository to which the change belongs. State it as a local path
    or as a name in a forge such as GitHub.
  - Suggest one branch name.

Do not implement anything. Do not change tracker state. Do not run compilers,
linters, or tests.

This message ends with the tracker reference. A `--` separator can come after
the reference. If the separator is there, the text after it gives additional
instructions from the user.

If there are additional instructions, follow them. If the additional
instructions conflict with the instructions above, the additional instructions
have priority.

Tracker reference (additional instructions after `--`):

$ARGUMENTS
