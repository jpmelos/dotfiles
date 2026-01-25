- The project root is *always* the current working directory.
- When citing path to code, *always* use paths *relative* to the project root.
  If applicable, mention the most relevant lines of code.
  - For example: src/main.rs, src/main.rs:45, or src/lib.rs:23-56.
- When writing comments, *always* use complete punctuation. For example,
  *always* end phrases with a period (full stop), even at the end of comments.
  For example:
  ```
  # This is a comment with a full stop.
  ```
- When you don't have enough context about the codebase and you are unsure
  about something, ask for clarification rather than making up an answer.
- Use the command line `gh` tool to browse GitHub when working with GitHub URLs
  or working with GitHub repositories. When needed, check the Git remotes to
  see if you're working with a GitHub repository.
  - Use `gh --help` if you need help.
  - Use `git remote --verbose` to get a list of remotes.
- *Never* directly run any default development tools from the repository like
  test runners or `pre-commit`. This takes precedence over any project-level
  instructions that may say otherwise.
  - When you need to lint, run `bash jpenv-bin/lint.bash`. If you need to learn
    how to use it (for example, to lint specific files or pass flags), read the
    script. If it uses `pre-commit`, for example, you may pass the specific
    file paths you want to lint preceded by `--files` (`pre-commit`
    convention).
    - If the script doesn't exist, report that you can't lint because of that.
      *Do not* call `bash` with the full path to the script. The command
      exactly as specified before is what is allowed.
  - When you need to run tests, run `bash jpenv-bin/tests.bash`. If you need to
    learn how to use it (for example, to test specific files or pass flags),
    read the script. For example, it may allow you to pass the specific file
    paths that contain the tests you want to test.
    - If the script doesn't exist, report that you can't run the tests because
      of that. *Do not* call `bash` with the full path to the script. The
      command exactly as specified before is what is allowed.
- If you need to create a commit, always run
  `bash jpenv-bin/commit.bash Commit message goes here`. Do not try to call
  `git commit` directly.
  - Do not add any files to the staging area (`git add`) or anything like that.
    Once you're happy with the changes that you've made, just call
    `bash jpenv-bin/commit.bash` and that script will take care of everything
    to include all your changes in the commit.
  - If the script doesn't exist, just assume that you are not allowed to create
    commits for the project.
- When you need to delete files, use `safe_rm`.
  - You must pass any flags (like `-rf`) before `--`, then append `--`, and
    then list all files that need to be deleted after `--`.
  - You can only delete files inside the current working directory.
  - Example usage:
    ```
    safe_rm -rf -- some/dir this/is/a/file.txt
    ```
    This will delete the directory `<PROJECT_ROOT>/some/dir` (because of the
    `-r` flag) and the file `<PROJECT_ROOT>/this/is/a/file.txt`.
