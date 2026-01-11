---
description: "Convert PRD in `jpenv-scratch/PRD.md` into `jpenv-scratch/prd.json`."
---

## The Task

Take a Product Requirements Document (PRD) in `jpenv-scratch/PRD.md` and
convert it into `jpenv-scratch/prd.json` according to the following guidelines
and rules.

## Output Format

```json
{
  "project": "[Project Name]",
  "description": "[Feature description from PRD title/intro]",
  "userStories": [
    {
      "id": 1,
      "title": "[Story title]",
      "description": "As a [user], I want [feature] so that [benefit]",
      "acceptanceCriteria": [
        "Criterion 1",
        "Criterion 2",
        "Criterion 3"
      ],
      "notes": "",
      "passes": false
    }
  ]
}
```

## Story Size: The Number One Rule

**Every story must be completable in one AI coding assistant session with a
context window of 150k tokens.**

An AI agent with a context window of 150k tokens will be processing one user
story per session with no memory of previous work. If a story is too big, the
AI agent will run out of context window before finishing and may produce lower
quality results.

### Examples of right-sized stories

- Add a database column and migration.
- Update a server action with new logic.
- Update a return payload of an API endpoint with a new set of fields.

### Stories that are too big

These stories need to be split out:

- Add authentication.
  - Split into: schema, middleware, login UI, session handling.
- Refactor the API.
  - Split into one story per endpoint or pattern.

**Rule of thumb:** If you cannot describe the change in 2-3 sentences, it is
already too big.

## Story Ordering: Dependencies First

Stories execute in priority order. Earlier stories must not depend on later
ones.

**Example of correct order:**

1. Schema/database changes (migrations).
2. Domain logic.
3. Service layer.
4. API layer.

## Acceptance Criteria: Must Be Verifiable

Each criterion must be something an AI agent can check **autonomously** and
**precisely**. Assume the AI agent has access to tools to run an automated test
suite and linting tools.

### Good criteria (verifiable)

- Add `status` column to `tasks` table with default `pending`.
- Add field `error` to payload of a given API endpoint.
- When certain criteria change, a given calculation should give a certain
  result.

### Bad criteria (vague)

- Works correctly.
- User can do X easily.
- Good UX.
- Handles edge cases.

## Conversion Rules

1. **Each user story becomes one JSON entry.**
2. **IDs**: Numeric, monotonically increasing by 1, and starting from 1.
3. **All stories**: `passes: false` and empty `notes`. The `notes` field is for
   a human to add context for the AI agent as necessary.

## Splitting Large PRDs

If a PRD has a big feature, split it:

**Original:** Add a user notification system.

**Split into:**

01. Create domain model and add `notifications` table to database.
02. Create service function to create notifications.
03. Create service function to retrieve notifications.
04. Create service function to update notifications.
05. Create service function to delete notifications.
06. Create REST API to create notifications.
07. Create REST API to retrieve notifications.
08. Create REST API to update notifications.
09. Create REST API to delete notifications.
10. Create GraphQL API to create notifications.
11. Create GraphQL API to retrieve notifications.
12. Create GraphQL API to update notifications.
13. Create GraphQL API to delete notifications.
14. Create service function to mark notification as read.
15. Create REST API to mark notification as read.
16. Create GraphQL API to mark notification as read.

Each is one focused, modular change that can be completed and verified
independently.
