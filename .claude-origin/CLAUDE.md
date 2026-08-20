# Critical

- **SINGLE BACKTICKS ONLY.** Use `` `value` ``, *never* ``` ``value`` ```. This
  applies *everywhere* without exception: code comments, docstrings, chat
  messages, commit messages, PR descriptions. Double backticks are reST syntax
  and must *never* appear in any output you produce.

# General

- *Never* use built-in tools like `AskUserQuestion` to ask questions. Instead,
  ask directly in the chat and wait for a response.
- When unsure about the codebase, ask for clarification rather than guessing.
- When planning (writing plans, specs, etc.), discuss the plan in the chat.
  *Never* write it to a file unless the user explicitly asks you to.
- The project root is *always* the current working directory.
- When citing code paths, *always* use paths *relative* to the project root,
  including the most relevant lines when applicable.
  - For example: src/main.rs, src/main.rs:45, or src/lib.rs:23-56.

# Code Style

- Document only the code that exists *now*. *Never* write comments or
  docstrings about planned work, future features, or concepts that are not in
  the codebase yet. A reader who sees only the current code, and knows nothing
  about the plan behind it, must understand the text fully.
- Document only the unit you are writing. *Never* describe the behavior or the
  implementation of another function, class, module, or layer in a comment or
  docstring. Name it and let the reader go read it there. Copied descriptions
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
  - To lint: `bash jpenv-bin/lint.bash`. Read the script to learn its usage
    (e.g., passing specific files). If it uses `pre-commit`, pass file paths
    preceded by `--files`.
  - To test: `bash jpenv-bin/tests.bash`. Read the script to learn its usage
    (e.g., passing specific test files).
  - If either script doesn't exist, report that you can't perform the action.
    *Always* use the exact commands above — never call `bash` with the full
    path to the script.
- To rename or delete files, use `safe_mv` and `safe_rm` instead of `mv` and
  `rm`. To delete directories, use `safe_rm -r` instead of `rmdir`. The API is
  otherwise identical.
- To find files or directories by name, use `rg --files | rg <pattern>` or
  `rg --files --glob '<pattern>'`. *Never* use `find` — you don't have
  permission to run it.
- If Write or Edit is denied on a file, *immediately* retry via a sibling path
  and `safe_mv` — do *not* stop and ask the user:
  - To write: create the content at `.bashrc.temp`, then
    `safe_mv .bashrc.temp .bashrc`.
  - To edit: first `safe_mv .bashrc .bashrc.temp`, edit `.bashrc.temp`, then
    `safe_mv .bashrc.temp .bashrc`.
- To manage the Git staging area and to commit, use these commands. Never
  call `git add`, `git restore`, or `git commit` directly.
  - To stage files, run `ai_git_add <path> ...`. It relays all arguments to
    `git add`.
  - To empty the staging area, run `ai_git_restore`. It takes no arguments.
    If you stage the wrong files, run this command and stage them again from
    zero.
  - To commit, run `ai_git_commit Commit message goes here`. This commits
    only the contents of the staging area.
  - To stage all changes and commit them in one step, run
    `ai_git_commit -a Commit message goes here`.
  - Only run any of these commands when the user explicitly asks for a commit.
  - *Never* delete a commit. Only a human can undo a commit.
  - If one of these scripts doesn't exist, assume that you are not allowed to
    do the related action.
- Use `git remote --verbose` to check in which service the repository is hosted
  on.
- When a tool call or command is denied due to permissions, read
  `~/.claude/settings.json` to discover which alternatives are allowed.

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

- In your responses, or when you write technical text (documentation, READMEs,
  runbooks, procedures, error messages, release notes, reports), obey these
  rules from ASD-STE100 Simplified Technical English:
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
    ", making", semicolons. Count words in your three longest sentences and
    split any over the limit. Collapse synonym rotation.
  - Do not apply these rules to marketing copy or brand writing.
