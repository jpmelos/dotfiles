---
name: aitodo
description: Implement or answer what is described in `AITODO` comments.
metadata:
  opencode/autoinvoke: false
---

Run `rg --no-messages AITODO .` to list all occurrences of `AITODO` in the
codebase. The command exits with status 1 when nothing matches. That case means
no work remains.

Read all occurrences and the context around them, because the match list gives
only the specific line that contains "AITODO", but some comments span more
lines.

Each comment is one of two kinds:

- A task: it asks you to implement, change, or fix something. Implement what it
  describes.
- A question: it asks something about the code, and does not ask for a change.
  Answer the question in the chat, then remove the `AITODO` comment from the
  code. Do not change anything else.

If a comment mixes both, do the task and answer the question, then treat it as
a task.
