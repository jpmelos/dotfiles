---
description: Save project facts to `jpenv-scratch/ai-memory` for future runs.
argument-hint: '[facts to remember]'
---

Save the facts below to project memory in `jpenv-scratch/ai-memory` from the
repository root.

The facts to save are:

```
$ARGUMENTS
```

## Check current memory

- Read `jpenv-scratch/ai-memory/index.md`.
- Read files from `jpenv-scratch/ai-memory/index.md` that overlap with the new
  facts.
- *NEVER* trust memory as truth. Check each overlapping claim against its
  source. If the source differs, use the source.
- Discard memory facts that the source contradicts.

## Save facts

- Save only durable facts that will help future runs.
- Update the file that already holds related facts.
- Create a new file only for a distinct topic.
- Name files by topic, for example `testing.md`.
- Keep each fact orthogonal to every other fact.
- Merge facts that overlap instead of duplicating them.
- Do not move review decisions out of `jpenv-scratch/ai-memory/reviews`.
- If `jpenv-scratch/ai-memory/reviews/index.md` exists, link to it from
  `index.md`. Do not list each review file in `index.md`.

## Keep the index

- Keep `index.md` as the entry point to all memory.
- List every memory file in `index.md` except review files.
- Add a short summary next to each entry that states what the file holds.
- Keep entries organized by topic.
- Put the most important entries first.
- Remove entries for deleted files.
