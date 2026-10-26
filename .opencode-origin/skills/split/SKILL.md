---
name: split
description: Split uncommitted changes into story-like micro-commits.
metadata:
  opencode/autoinvoke: false
---

Split the current uncommitted changes into small modular self-contained
micro-commits such that when read chronologically, they tell the story of the
change.

Do not edit file content. Create only commits from work that already exists in
the work tree.

If there is no uncommitted work, do nothing.

## 1. Study the change

Read affected files and related context. Think very hard.

Identify logical units in the change. Note how units depend on each other.

## 2. Plan micro-commits

Group the change into small modular self-contained units. Apply these rules:

- Each micro-commit holds one idea.
- Each micro-commit builds on prior micro-commits.
- Each micro-commit leaves the tree in a coherent state.
- The full sequence tells the story of the change in chronological order.
- Early micro-commits lay the foundation.
- Later micro-commits add behavior and polish.
- Tests and docs form later micro-commits when they exist.

Write one commit message per micro-commit. Apply these rules:

- Use imperative mood for the title.
- Keep the title short, at most 50 characters.
- Use single backticks for identifiers in the message.
- Never use double backticks in the message.
- Describe what the micro-commit does and why it matters.

Order micro-commits from foundation to finish. Present the ordered plan with
title and scope per micro-commit.

## 3. Create micro-commits

Use `git add` and `git apply --cached` to stage. Use `ai_git_commit` to commit.

For each micro-commit in plan order, complete these actions:

- Run `git add <path> ...` with the file paths of the micro-commit. Two
  micro-commits can change the same file when each change forms a separate
  logical unit. When one file holds two units, stage hunks with
  `git apply --cached`.
- Run `git status --short` and `git diff --cached` to confirm that the stage
  matches the plan.
- If the stage does not match the plan, run `ai_git_restore`. Stage again from
  scratch.
- Run `ai_git_commit <message>` to commit the staged content.

If a stage is empty or a commit fails, stop. Report the state in the chat. Do
not continue with later micro-commits.

## 4. Verify and report

Run `git status --short` to confirm that no planned change remains uncommitted.

Run `git log --oneline -n <count>` for the new commits to confirm the story
order.

Do not run compilers, linters, or tests.

Present the ordered list of new micro-commits with titles. Describe what the
user can now do with the new history.

If there are additional instructions, follow them. If the additional
instructions conflict with the instructions above, the additional instructions
have priority.

Additional instructions appear in the user message after this skill block.
Follow them.
