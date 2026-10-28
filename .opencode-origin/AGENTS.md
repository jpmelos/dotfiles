# Critical

- **SINGLE BACKTICKS ONLY.** Use `` `value` ``, *never* ``` ``value`` ```. This
  applies *everywhere* without exception: code comments, docstrings, chat
  messages, commit messages, PR descriptions, and everything else. Double
  backticks, like the ones used in reST syntax, must *NEVER* appear in any
  output you produce.

# General

- When you report work, describe only what the user can now do. Never mention
  code changes, files, functions, or implementation details.
- When you mention an issue, PR, ticket, or similar by reference (number, code,
  etc.), always add a short description of what it is about. The user does not
  remember references from memory.
- *Never* use tools to ask questions. Instead, ask directly in the chat and
  expect a response in the user's turn.
- When unsure about the codebase, ask for clarification rather than guessing.
- When planning (writing plans, specs, etc.), discuss the plan in the chat.
  *Never* write it to a file unless the user explicitly asks you to.
- The project root is *always* the current working directory.
- When you need a temporary file that will not be committed, create it under
  `/tmp`. *Never* create it under `~/devel`.
- When citing code paths, *always* use paths *relative* to the project root,
  including the most relevant lines when applicable.
  - For example: src/main.rs, src/main.rs:45, or src/lib.rs:23-56.
  - When referring to code outside the current working directory, use `..`
    prefixes as needed.

# Titles and Descriptions

- Apply these rules to PRs, issues, and tickets.
- Keep each title short, at most 50 characters.
- Describe in the title what the change does or what the issue requests.
- Keep each body very concise and to the point.
- Make each body complete in isolation from parent items and related items.
- Write each body for a human reader in very plain and direct terms.
- Start each body with a section named User Perspective or Business
  Perspective.
- Explain in that section the change from a user and business view.
- Omit function names, variable names, layer names, and database terms unless a
  term explains a business change.
- If the change alters what the user sees or does, state the current behavior
  and the new behavior after release.
- If the change has no user effect, state the prior business problem and the
  new business state.
- Add after that section a section named Technical Details if the item holds
  development work.
- Explain in that section high-level technical choices of interest to a lead or
  manager.
- Focus in that section on architecture, performance, safety, and security.
- Omit from that section function names, variable names, and layer names.
- Emit each title and each body as raw Markdown, ready to paste into the
  tracker.
- Put each title alone inside one code block.
- Put each body inside a separate code block tagged as `markdown`.
- Show raw Markdown syntax in the block for verbatim copy.
- Include headings, lists, links, and inline code as raw syntax.
- Do not render bodies as formatted Markdown outside code blocks.
- If a body holds code blocks of its own, use a fence of four backticks for the
  outer block.

# Code Style

- Document only the code that exists *now*. *Never* write comments or
  docstrings about planned work, future features, or concepts that are not in
  the codebase yet. A reader who sees only the current code, and knows nothing
  about the plan behind it, must understand the text fully.
- Document only the unit you are writing. *Never* describe the behavior or the
  implementation of another function, class, module, or layer in a comment or
  docstring. Name it and let the reader go read it there. Crossed descriptions
  couple the layers and go stale.
- Prefer descriptive variable names over shorter ones (e.g., `thread_id`
  instead of `tid`). The only exceptions are very short for-loops, Python
  comprehensions, or similar structures.
- *Always* use complete punctuation in comments, including a period (full stop)
  at the end. For example:
  ```
  # This is a comment with a full stop. Even after the last phrase.
  ```

# Tools

- *Never* directly run default development tools from the repository (test
  runners, `pre-commit`, etc.). This takes precedence over any project-level
  instructions.
  - To lint: `./jpenv-bin/lint`. Read the command to learn its usage (e.g.,
    passing specific files). If it uses `pre-commit`, pass file paths preceded
    by `--files`.
  - To test: `./jpenv-bin/tests`. Read the command to learn its usage (e.g.,
    passing specific test files).
  - If either command doesn't exist, report that you can't perform the action.
  - *Always* use the exact commands above, and add arguments as needed.
- Regarding `git`:
  - Read-only `git` commands run without explicit permission. Examples:
    `git log`, `git show`, `git status`.
  - *Never* run a `git` command with side effects unless the user explicitly
    asks for that exact action. Staging and committing belong to the user
    alone. Leave your work unstaged and report what you changed instead, unless
    you've been explicitly asked otherwise.
  - When the user asks you to stage or to commit, use these commands.
    - To stage files, run `git add <path> ...`.
    - To stage hunks, run `git apply --cached <patch> ...`.
    - To empty the staging area, run `ai_git_restore`. It takes no arguments.
      If you stage the wrong files, run this command and stage them again from
      zero.
    - To commit, run `ai_git_commit Commit message goes here`. This commits
      only the contents of the staging area.
    - To stage all changes and commit them in one step, run
      `ai_git_commit -a Commit message goes here`.
    - To create a new branch at a commit, run
      `ai_git_new_branch <branch-name> <sha>`. This creates a branch that
      points at the commit.
    - Name new branches as `jpmelos-{what the changeset does}`.
      - For example: `jpmelos-index-numbers-by-assigned-group`.
      - When the work addresses an issue, include the issue number as
        `jpmelos-{issue number}-{what the changeset does}`.
        - For example: `jpmelos-comms-1705-clear-stale-pins-on-auto-agents`.
    - `ai_git_reset <ref>` moves the current branch to `ref` and keeps commit
      changes in the worktree.
      - The command fails unless `ref` is an ancestor of `HEAD` and each commit
        after `ref` exists only on the current branch.
      - After the reset, the original tip remains in `ORIG_HEAD`.
      - To undo recent commits but keep their changes in the worktree, run
        `ai_git_reset <ref>`.
      - To change an older commit on the current branch, use this sequence.
        - Record the commit messages after the target commit.
        - Run `ai_git_reset <parent-of-target>`.
        - Edit files to fold the fix into the target commit.
        - Recreate each undone commit in order with `ai_git_commit`.
  - *Never* delete a commit, except with `ai_git_reset` after the user asks to
    change history.
  - *Never* call a `git` command with side effects directly (`git restore`,
    `git commit`, etc), except for `git add` and `git apply`.
- To rename or delete files, use `safe_mv` and `safe_rm` instead of `mv` and
  `rm`. To delete directories, use `safe_rm -r` instead of `rmdir`. The CLI is
  otherwise identical to that of `mv` and `rm` respectively.
- To find files or directories by name, use `rg --files | rg <pattern>` or
  `rg --files --glob '<pattern>'`. *Never* use `find`.
- If `Write` or `Edit` is denied on a file, *immediately* retry via a sibling
  path and `safe_mv` — do *not* stop and ask the user.
  - To write: create the content at `.bashrc.temp`, then
    `safe_mv .bashrc.temp .bashrc`.
  - To edit: first `safe_mv .bashrc .bashrc.temp`, edit `.bashrc.temp`, then
    `safe_mv .bashrc.temp .bashrc`.
- When a tool call or command is denied due to permissions, read
  `~/.config/opencode/opencode.json` to discover the alternatives allowed, if
  any.

# Browser

`agent-browser` controls a real Chromium browser. It opens pages, reads
content, and performs input actions. It works with dynamic pages and logged-in
sessions.

`WebSearch` finds pages. `WebFetch` reads simple static pages. `agent-browser`
handles pages that `WebFetch` cannot read and tasks that need clicks, text
entry, or login.

`agent-browser -h` lists the current commands and options.

# Environment

- You are running inside a Docker container.
- Services on `localhost`, `127.0.0.1`, or other loopback interfaces are
  actually running on the host machine. Access them via `host.docker.internal`.
- Source code for dependencies may be available under `~/devel`. Projects are
  either directly inside `~/devel` or organized in subdirectories named after
  the owning organization. Use these to inspect dependency interfaces, types,
  or behavior. Always verify the checked-out version is compatible with what
  the current project uses before relying on it.
  <!-- DEPENDENCIES_LIST -->

# Writing style

- In your responses, or when you write technical text (comments, documentation,
  READMEs, runbooks, procedures, error messages, release notes, reports), obey
  these rules from ASD-STE100 Simplified Technical English:
  - CLASSIFY FIRST. Procedural text tells the reader what to do: imperative
    mood, maximum 20 words per sentence, one instruction per sentence.
    Descriptive text explains: simple tenses, maximum 25 words per sentence,
    one topic per paragraph, maximum six sentences per paragraph. Never mix the
    two in one passage.
  - VERBS. Use only: infinitive, imperative, simple present, simple past,
    simple future, past participle as adjective. No present perfect ("has
    completed" → "completed"). No "-ing" verb forms ("making it easy" → new
    sentence). Active voice; passive only in descriptions when the agent is
    unknown. Approved modals: can, will, must. Banned: should, would, may,
    might, could. For "should": write "must" if required, delete if optional.
  - SENTENCES. Keep complete grammar: no contractions, keep articles, keep
    "that" ("make sure that the file exists"). Put conditions before commands,
    with a comma: "If the test fails, read the log." No semicolons — write two
    sentences. Use a vertical list for more than two items or steps.
  - WORDS. One word, one meaning, for the whole document: pick one of
    check/verify/confirm and keep it. Noun chains of maximum three words; break
    longer ones with prepositions ("the timeout value for the connection
    pool"). Delete words that carry no fact: simply, seamlessly, robust,
    powerful, comprehensive, leverage, "in order to", "it is worth noting".
    Replace: utilize → use, prior to → before, in the event that → if, e.g. →
    for example. American spelling.
  - WARNINGS. Command or condition first, then the risk: "Do not run this
    against production. The command deletes rows."
  - NEVER TOUCH. Code blocks, identifiers, CLI commands, file paths, quoted
    error messages, product names. Each counts as one word toward sentence
    limits.
  - SELF-CHECK before returning: scan for contractions, "has been", "should",
    "making", semicolons. Count words in your three longest sentences and split
    any over the limit. Collapse synonym rotation.
  - Do not apply these rules to marketing copy or brand writing.
