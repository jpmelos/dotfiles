---
description: Implement or answer what's described in `AITODO` comments.
disable-model-invocation: true
---

Here are all occurrences of `AITODO` in this codebase:

!`rg --no-messages AITODO . || true`

Read all occurrences and the context around them, because I've only given you
the specific line that contains "AITODO", but some comments may be multi-line.

Each comment is one of two kinds:

- A task: it asks you to implement, change, or fix something. Implement what it
  describes.
- A question: it asks something about the code, and does not ask for a change.
  Answer the question in the chat, then remove the `AITODO` comment from the
  code. Do not change anything else.

If a comment mixes both, do the task and answer the question, then treat it as
a task.
