---
description: Convert a feature or change plan into tickets.
argument-hint: plan_file=PLAN_FILE tokens_per_ticket=TOKENS_PER_TICKET
---

## Important Context Information

Arguments:

```
$ARGUMENTS
```

Parse the following information from the arguments:

- `plan_file`: The Markdown file containing the plan to convert.
- `tokens_per_ticket`: (Optional.) The maximum number of tokens per ticket.
  Default to 150,000.

## The Task

Take the plan in `plan_file` and convert it into tickets in a JSON file
`tickets_file` according to the following guidelines and rules.

Study the project and the plan to understand the relevant aspects specific to
the project.

- For example, if you're going to create or change a REST API, make sure to
  understand how REST APIs work in the project.
- Make sure you understand all project-specific terms and jargons. If you see
  terms whose meaning depend on the project, like "service layer", make sure
  you understand them completely before planning.
- Include these details in the ticket descriptions as necessary to enable work
  and set up your colleagues for success.

Output the resulting JSON file to the same directory as the `plan_file` using
the same filename as the `plan_file` but with the file extension
`.tickets.json`. For example, if the plan file is `feature-x.plan.md`, name the
tickets file as `feature-x.tickets.json`.

Once you create the file, run `bash ~/bin/ralph --validate plan_file` and fix
any validation errors.

## Output Format

```json
{
  "project": "[Project Name]",
  "description": "[Detailed description of the implementation work]",
  "tickets": [
    {
      "id": 1,
      "title": "[Ticket Title]",
      "description": "The description.",
      "acceptanceCriteria": [
        "Criterion 1",
        "Criterion 2",
        "Criterion 3"
      ],
      "notes": [],
      "done": false
    }
  ]
}
```

The title must be brief, five to ten words maximum, to keep logs scannable.

## Ticket Size: The Number One Rule

**Every ticket must be completable in one AI coding assistant session with a
context window of `tokens_per_ticket` tokens.** Each ticket will correspond to
a single Git commit and should be focused on a single, modular change that is
easy to review and verify.

An AI agent with a context window of `tokens_per_ticket` tokens will be
processing one ticket per session with no memory of previous work. If a ticket
is too big, the AI agent will run out of context window before finishing and
may produce lower quality results. If a ticket is too small, the AI agent will
waste tokens on overhead and setup, reducing overall efficiency. The tickets
described in the `plan_file` can be split or merged as necessary to optimize
for this rule.

### Examples of right-sized tickets

- Add a database column and a corresponding migration file.
- Update a service function and write tests for it.
- Update a return payload of an API endpoint with a new set of fields and
  update the API endpoint tests.

### Including Tests

It is acceptable to implement tests for multiple tickets at once in a single
separate ticket when the tickets are related and share similar test logic. For
example, integration tests are better implemented in a single ticket towards
the end of the plan rather than updated piecemeal for each ticket.

### Tickets that are too big

These tickets need to be split out:

- Add authentication.
  - Split into: schema updates and tests, middleware updates and tests, login
    endpoint, session handling, tests for the login endpoint and session
    handling, integration tests.
- Refactor the API.
  - Split into one ticket per endpoint, middleware, or pattern.

**Rule of thumb:** If you cannot describe the change in 2-3 sentences, it is
already too big.

## Ticket Ordering: Dependencies First

Tickets execute in priority order. Earlier tickets must not depend on later
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

1. **Each ticket becomes one JSON entry.**
2. **IDs**: Numeric, monotonically increasing by 1, and starting from 1.
3. **All tickets**: `done: false` and `notes: []` (empty array). The `notes`
   field is for a human to add context for the AI agent as necessary.

## Splitting Large Tickets from the Plan into Smaller Ones

If a ticket in the plan is too big, split it:

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

## Output

- **Format:** JSON (`*.tickets.json`).
- **Location:** Same directory as the `plan_file`.
