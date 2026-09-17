---
name: linear-issue
description: Create a Linear issue with a concise title, an implementation-ready description, blocking relations, and a milestone.
argument-hint: what the issue is about [-- team, project, or other hints]
disable-model-invocation: true
allowed-tools: mcp__linear-server__save_issue
---

Create a Linear issue for this request:

```
$ARGUMENTS
```

Follow the steps below in order. Do not skip a step.

## 1. Locate the team and the project

Identify the Linear team and the project that the issue belongs to.

- If the request names them, use those.
- If the request does not name them, infer them from the current repository
  and from recent conversation context. Resolve the names against the teams
  and projects that exist in Linear.
- If more than one candidate remains, stop and ask the user which one to use.

## 2. Read the project

Before you write anything, read the existing state of the project:

- List all issues in the project, with their title, description, status,
  milestone, and URL. Page through all results.
- List the milestones of the project.
- Read the project itself, including its description and its goals.

If an existing issue already covers the request, stop and report it to the
user instead of creating a duplicate.

## 3. Write the title

Write one line of at most 70 characters. Start with a verb in the imperative
mood. State the outcome, not the activity. Do not include the team name, the
project name, or an issue type prefix.

Good: `Add retry with backoff to the webhook delivery worker`.
Bad: `Webhooks: investigate and improve reliability`.

## 4. Write the description

Write the description in Markdown for an agent that will implement the issue
with no other context. The agent must be able to start work from the
description alone. Use these sections, in this order. Omit a section only if
it has no content.

- **Context.** Why this work exists. Name the user-facing or technical problem
  and the relevant part of the system.
- **Goal.** The end state in one or two sentences.
- **Scope.** What is included. Then a short list of what is explicitly out of
  scope.
- **Implementation notes.** Concrete pointers: file paths, modules, functions,
  data models, external services, and known constraints. Cite the code you
  inspected with paths relative to the repository root. Record decisions
  already made, so that the implementer does not reopen them.
- **Acceptance criteria.** A checklist. Each item must be verifiable by a test
  or by a manual check.
- **References.** Links to related issues, pull requests, documents, and
  discussions.

Use single backticks for identifiers. Write real newlines, not escape
sequences. Keep the description as long as needed and no longer.

## 5. Determine the blocking relations

Compare the new issue against every open issue that you listed in step 2.

- An existing issue **blocks** the new one if the new work cannot start or
  cannot be verified until that issue is done.
- The new issue **blocks** an existing one if that issue depends on the new
  work.
- Do not record blocking relations for issues that are merely related. Mark
  those as related only when the connection helps the implementer.

Refer to issues by their identifier (for example `ENG-123`).

## 6. Choose the milestone

Pick the milestone from step 2 that matches the goal of the new issue. Use
the blocking relations as a signal: an issue cannot live in a milestone that
comes before the milestone of an issue that blocks it. If the project has
milestones and none of them fits, leave the milestone empty and say so. If
the project has no milestones, skip this step.

## 7. Confirm with the user

Show the user the full draft before you create anything:

- Team and project.
- Title.
- Description, verbatim.
- Blocking relations, with the identifier and title of each related issue.
- Milestone.

Then stop and wait for the user to approve or to request changes. Do not use
a tool to ask. Ask directly in the chat.

## 8. Create the issue

After approval, create the issue in one call, with:

- The team and the project.
- The title and the description.
- The blocking relations from step 5.
- The milestone from step 6.

Do not set an assignee, a priority, a state, or labels unless the user asked
for them.

Report the identifier and the URL of the created issue.
