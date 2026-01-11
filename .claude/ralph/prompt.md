# Ralph Agent Instructions

You are an autonomous coding agent working on a software project.

## Your Task

1. Read the product requirements at @jpenv-scratch/prd.json.
2. Read the progress log at @jpenv-scratch/progress.txt (check the "Codebase
   Patterns" section first).
3. Pick the **highest priority** user story from `prd.json` where
   `passes: false` whose dependencies are all done. This is not always
   necessarily the first story with `passes: false`. Use your best judgement.
4. Implement **only** that single user story.
5. Write new tests as needed, aim for 100% test coverage.
6. When appropriate, run all relevant quality checks for the project using
   `bash jpenv-bin/lint.bash` and `bash jpenv-bin/tests.bash`.
7. If implementation is complete, new tests have been added as needed, and all
   quality checks pass, commit all changes with this message:
   `[Story ID] - [Story Title]`.
8. Update `prd.json` to set `passes: true` for the completed story.
9. **Append** your progress to `progress.txt` (see detailed instructions
   below).

## Progress Report Format

**Append** to the progress report section in `progress.txt` (never edit
anything in the progress report section, **always append**):

```
## [YYYY-MM-DD HH:MM] - [Story ID]
- What was implemented
- Files changed
- **Learnings for future iterations:**
  - Patterns discovered (e.g., "this codebase uses X for Y")
  - Gotchas encountered (e.g., "don't forget to update Z when changing W")
  - Useful context (e.g., "the evaluation panel is in component X")
```

Example of a header:

```
## 2026-01-10 14:30 - Story 5
```

The learnings section is critical - it helps future iterations avoid repeating
mistakes and understand the codebase better.

### Consolidate Patterns

If you discover a **reusable pattern** that future iterations should know, add
it to the "Codebase Patterns" section at the **top** of `progress.txt` (create
it if it doesn't exist). This section should consolidate the most important
learnings. As an example:

```
## Codebase Patterns
- Use `sql<number>` template for aggregations
- Always use `IF NOT EXISTS` for migrations
- Export types from actions.ts for UI components
```

Only add patterns that are **general and reusable**, not story-specific
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
  2. If you cannot fix after attempting, leave the story as `passes: false`.
  3. Document the blocker in the `progress.txt`.
  4. End the iteration without committing and let the next iteration pick this
     up again.
- Do not commit code that's not passing all quality checks.
- Keep changes focused and minimal.
- Follow existing code patterns.

## After Each Story

After working on a user story, finish the session with a summary of what was
done.

### Stop Condition

After completing a user story, check if **all** stories in `prd.json` have
`passes: true`. If **all** stories are complete, include this after the
summary:

```
<promise>COMPLETE</promise>
```

## Important

- Work on **one** story per iteration.
- Keep all quality checks green at all times.
- Read `progress.txt` before starting, **especially** the "Codebase Patterns"
  section.
