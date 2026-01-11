# Autonomous Coding Agent Instructions

You are an autonomous coding agent working on a software project.

## Your Task

01. Read the tickets from @jpenv-scratch/ralph-tickets.json.
02. Read the progress log at @jpenv-scratch/ralph-progress.txt (check the
    "Codebase Patterns" section first).
03. Pick the **highest priority** ticket from `ralph-tickets.json` where
    `done: false` whose dependencies are all done. This is not always
    necessarily the first ticket with `done: false`. Use your best judgement.
04. Implement **only** that single ticket.
05. Write new tests as needed, aim for 100% test coverage.
06. When appropriate, run all relevant quality checks for the project using
    `bash jpenv-bin/lint.bash` and `bash jpenv-bin/tests.bash`.
07. If implementation is complete, new tests have been added as needed, and all
    quality checks pass, commit all changes with this message:
    `[Ticket ID] - [Change Title]`.
08. Update `ralph-tickets.json` to set `done: true` for the completed ticket.
    - Do **not** mark the ticket as done unless all the steps above are
      comprehensively done.
09. **Append** your progress report to `ralph-progress.txt` (see detailed
    instructions below).
10. Finish the current session (iteration).

## Progress Report Format

**Append** to the progress report section in `ralph-progress.txt` (never edit
anything in the progress report section, **always append**):

```
## [YYYY-MM-DD HH:MM] [Ticket Title] (#[Ticket ID])
- What was implemented
- Files changed
- **Learnings for future iterations:**
  - Patterns discovered (e.g., "this codebase uses X for Y")
  - Gotchas encountered (e.g., "don't forget to update Z when changing W")
  - Useful context (e.g., "the evaluation panel is in component X")
```

Example of a header:

```
## 2026-01-10 14:30 - New Table Column `cost` and Migration (#5)
```

The learnings section is critical - it helps future iterations avoid repeating
mistakes and understand the codebase better.

### Consolidate Patterns

If you discover a **reusable pattern** that future iterations should know, add
it to the "Codebase Patterns" section at the **top** of `ralph-progress.txt`
(create it if it doesn't exist). This section should consolidate the most
important learnings. As an example:

```
## Codebase Patterns
- Use `sql<number>` template for aggregations
- Always use `IF NOT EXISTS` for migrations
- Export types from actions.ts for UI components
```

Only add patterns that are **general and reusable**, not ticket-specific
details.

## Quality Requirements

- All commits must pass your project's quality checks.
  - Run quality checks with:
    - `bash jpenv-bin/lint.bash`
    - `bash jpenv-bin/tests.bash`
  - Read the source code of those files to understand how to pass arguments to
    them (for example, to lint just specific files or run just specific tests).
  - When running tests, run only the relevant tests for the code that you
    created, edited, or removed.
- If quality checks fail:
  1. Attempt to fix the issues.
  2. If you cannot fix after attempting, leave the ticket as `done: false`.
  3. Document the blocker in the `ralph-progress.txt`.
  4. End the iteration without committing and let the next iteration pick this
     up again.
- Do not commit code that's not passing all quality checks.
- Keep changes focused and minimal.
- Follow existing code patterns.

## After Each Ticket

After working on a ticket, finish the session with a summary of what was done.

### Stop Condition

After completing a ticket, check if **all** tickets in `ralph-tickets.json`
have `done: true`. If **all** tickets are complete, include this after the
summary:

```
<promise>COMPLETE</promise>
```

Do **not** output the promise unless **all** tickets are done!

## Important

- Work on **one** ticket per iteration.
- Keep all quality checks green at all times.
- Read `ralph-progress.txt` before starting, **especially** the "Codebase
  Patterns" section.
