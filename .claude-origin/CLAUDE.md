# Critical

- *Always* use single backticks for inline code references (Markdown style,
  e.g., `value`). *Never* use double backticks (reST style, e.g., ``value``).
  This applies *everywhere*: code comments, chat messages, commit messages,
  PR descriptions — no exceptions.

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
  `rm`. The API is identical.
- To commit, always run `ai_commit Commit message goes here`. Never call
  `git commit` directly.
  - Do not stage files (`git add`) or similar. Just call `ai_commit` and it
    will include all changes.
  - If the script doesn't exist, assume you are not allowed to create commits.
- Use the `gh` CLI to interact with GitHub URLs and repositories.
  - Use `gh --help` for help.
  - Use `git remote --verbose` to check if the repository is on GitHub.
- When a tool call or command is denied due to permissions, read
  `~/.claude/settings.json` to discover which alternatives are allowed.

# Environment

- You are running inside a Docker container.
- Services on `localhost`, `127.0.0.1`, or other loopback interfaces are
  actually running on the host machine. Access them via `host.docker.internal`.
- Source code for dependencies may be available under `~/devel`. Projects are
  either directly inside `~/devel` or organized in subdirectories named after
  the owning organization. Look there when you need to inspect dependency
  interfaces, types, or behavior.
