---
description: Resolve rebase conflicts and continue the rebase.
argument-hint: '[additional instructions]'
disable-model-invocation: true
---

You are in the middle of a rebase with a conflict. The rebase stops for each
conflict. You resolve each conflict in turn.

Complete the loop below. Repeat until the rebase ends.

1. Inspect and resolve the conflict.
2. Stage all the changes.
3. Continue the rebase: Run `ai_git_rebase_continue`.
4. Repeat or report.
   - If the command reports a new conflict, return to section 1.
   - If the command completes the rebase, report the result in the chat.
   - If the command fails for another reason, stop. Report the state in the
     chat.

If there are additional instructions, follow them. If the additional
instructions conflict with the instructions above, the additional instructions
have priority.

Follow these additional instructions:

```
$ARGUMENTS
```
