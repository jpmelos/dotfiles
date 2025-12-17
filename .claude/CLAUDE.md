- The project root is *always* the current working directory.
- When citing path to code, *always* use paths *relative* to the project root.
  If applicable, mention the most relevant lines of code.
- When writing comments, *always* use complete punctuation. For example,
  *always* end phrases with a period (full stop), even at the end of comments.
- Use the command line `gh` tool to browse GitHub when working with GitHub URLs
  or working with GitHub repositories. When needed, check the Git remotes to
  see if you're working with a GitHub repository.
- *Never* directly run any default development tools from the repository like
  test runners or `pre-commit`. This takes precedence over any project-level
  instructions that may say otherwise.
  - When you need to lint, run `bash jpenv-bin/lint.bash`. If applicable, pass
    the specific file paths you want to lint. If the script doesn't exist,
    report that you can't lint because of that.
  - When you need to run tests, run `bash jpenv-bin/tests.bash`. If applicable,
    pass the specific file paths that contain the tests you want to test. If
    the script doesn't exist, report that you can't run the tests because of
    that.
    - Consider specific test harness formats, like whether you can pass test
      names in `pytest` format for Python projects, `cargo test` or
      `cargo nextest` format for Rust projects.
