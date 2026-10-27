---
description: Split uncommitted changes into story-like micro-commits.
argument-hint: '[additional instructions]'
disable-model-invocation: true
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

Group micro-commits into PRs. Apply these rules:

- Put micro-commits that must deploy together in one PR group.
- Put micro-commits that work alone in a separate PR group.
- List each PR group with its micro-commits in plan order.
- When the plan holds more than one PR group, list one new branch name for each
  PR group.

All micro-commits in one PR deploy together. The micro-commits in separate PRs
deploy at different times. The separate PRs reach production with days of
difference. No time guarantee exists across separate PRs.

Order micro-commits from foundation to finish:

- Include the PR groups in the plan.
- Present the plan in the chat with the title, the scope, and the explanation
  for each micro-commit.
- Ask the user for approval before you continue to section 3.
- If the user requests changes, revise the plan.
- Present the revised plan in the chat.
- Continue only after the user approves the plan.
- Do not start section 3 without approval.

## 3. Create micro-commits

Use `git add` and `git apply --cached` to stage. Use `ai_git_commit` to commit.
Use `ai_git_new_branch` to create branches.

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

After the micro-commits, create branches. Apply these rules:

- If the plan holds one PR group, create no branch.
- If the plan holds more than one PR group, create one branch at the tip of
  each PR group.
- Run `git log --oneline -n <count>` to find each tip SHA.
- Run `ai_git_new_branch <branch-name> <sha>` for each tip with the branch name
  from the plan.

If a stage is empty or a commit fails, stop. Report the state in the chat. Do
not continue with later micro-commits.

If a branch creation fails, stop. Report the state in the chat.

## 4. Verify and report

Run `git status --short` to confirm that no planned change remains uncommitted.

Run `git log --oneline -n <count>` for the new commits to confirm the story
order.

Do not run compilers, linters, or tests.

Present the ordered list of new micro-commits with titles and new branches.
Describe what the user can now do with the new history.

If there are additional instructions, follow them. If the additional
instructions conflict with the instructions above, the additional instructions
have priority.

Follow these additional instructions:

```
$ARGUMENTS
```
