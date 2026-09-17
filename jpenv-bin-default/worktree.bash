#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND" >&2' ERR

#: j-execute

#/ Manage git worktrees of the repository that holds the current directory.
#/
#/ Worktrees live next to the main repository, in a directory named after it
#/ with a `_worktree` suffix. Each worktree directory is named after its
#/ branch.
#/
#/ Subcommands:
#/   new <branch>        Create a worktree for the branch and move into it.
#/                       When the branch does not exist, create it from the
#/                       main branch. When the worktree already exists, only
#/                       move into it.
#/   rm [<branch>]       Remove the worktree and its branch (the current
#/                       worktree when no argument is given), even when it
#/                       has uncommitted changes, then move into the main
#/                       repository.
#/   ls                  List all existing worktrees.

# The directory that the caller ran `j` from. Resolve it before any subcommand
# deletes it.
caller_dir="$(pwd -P)"

if ! git_common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2> /dev/null)"; then
    echo "Error: not inside a git repository." >&2
    exit 1
fi
main_repo_dir="$(dirname "$git_common_dir")"
worktrees_base_dir="$(dirname "$main_repo_dir")/$(basename "$main_repo_dir")_worktree"

# Personal files that git does not track. A worktree gets a link to each one
# that exists in the main repository and is missing from the worktree.
personal_files=(
    ".autoenv.enter"
    ".autoenv.leave"
    ".nvim.lua"
    "jpenv-bin"
    "jpenv-ripgreprc"
    "jpenv-scratch"
)

# Branch names can contain characters such as `/`. Derive a flat directory
# name from the branch name.
dir_name_from_branch() {
    echo "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -E 's/[^a-z0-9_-]+/-/g; s/^[^a-z0-9]+//'
}

# Print the path of the worktree that has the branch checked out. Print
# nothing when no worktree has it.
worktree_path_for_branch() {
    git worktree list --porcelain \
        | awk -v ref="branch refs/heads/$1" '
            /^worktree / { path = substr($0, 10) }
            $0 == ref { print path; exit }
        '
}

subcommand="${1:-}"
case "$subcommand" in
    new)
        branch_name="${2:-}"
        if [ -z "$branch_name" ]; then
            echo "Error: 'new' needs a branch name." >&2
            exit 1
        fi

        worktree_path="$worktrees_base_dir/$(dir_name_from_branch "$branch_name")"

        if [ -e "$worktree_path" ]; then
            echo "Worktree already exists at: $worktree_path"
            echo "/j-execute"
            echo "cd $worktree_path"
            exit 0
        fi

        mkdir -p "$worktrees_base_dir"
        # Drop entries of worktrees whose directories are gone, so that a
        # stale entry at the same path does not block the new worktree.
        git worktree prune

        if git show-ref --verify --quiet "refs/heads/$branch_name"; then
            git worktree add "$worktree_path" "$branch_name"
        elif git fetch origin "$branch_name" 2> /dev/null; then
            # The branch exists only on the remote. Track it.
            git worktree add --track -b "$branch_name" "$worktree_path" \
                "origin/$branch_name"
        else
            main_branch="$(git main-branch)"
            git worktree add -b "$branch_name" "$worktree_path" "$main_branch"
        fi

        echo

        for personal_file in "${personal_files[@]}"; do
            [ -e "$main_repo_dir/$personal_file" ] || continue
            if [ -e "$worktree_path/$personal_file" ] \
                || [ -L "$worktree_path/$personal_file" ]; then
                continue
            fi
            ln -s "$main_repo_dir/$personal_file" "$worktree_path/$personal_file"
            echo "Symlinked $personal_file"
        done

        if [ -e "$worktree_path/.autoenv.enter" ] && command -v autoenv-manage &> /dev/null; then
            echo
            echo "========= output: autoenv ======================================"
            autoenv-manage authorize "$worktree_path"
            echo "========= output: autoenv ======================================"
        fi

        echo
        echo "Done! Worktree created at: $worktree_path"

        echo "/j-execute"
        echo "cd $worktree_path"
        ;;
    rm)
        branch_name="${2:-}"
        if [ -n "$branch_name" ]; then
            worktree_path="$(worktree_path_for_branch "$branch_name")"
            if [ -z "$worktree_path" ]; then
                echo "Error: no worktree has branch '$branch_name' checked out." >&2
                exit 1
            fi
        else
            worktree_path="$(git rev-parse --show-toplevel)"
            # Empty on a detached HEAD.
            branch_name="$(git branch --show-current)"
        fi

        worktree_git_dir="$(git -C "$worktree_path" rev-parse --path-format=absolute --git-dir)"
        if [ "$worktree_git_dir" = "$git_common_dir" ]; then
            echo "Error: $worktree_path is the main repository, not a worktree." >&2
            exit 1
        fi

        worktree_real_path="$(realpath "$worktree_path")"

        # The worktree directory is about to disappear. Run the rest from the
        # main repository, which outlives it.
        cd "$main_repo_dir"

        echo "Removing worktree: $worktree_path"
        git worktree remove --force "$worktree_path"
        if [ -n "$branch_name" ]; then
            git branch -D "$branch_name"
        fi

        echo "/j-execute"
        if [[ "$caller_dir" == "$worktree_real_path" || "$caller_dir" == "$worktree_real_path"/* ]]; then
            # The shell that evaluates these commands is still inside the
            # worktree directory, which no longer exists. autoenv runs leave
            # hooks by changing into the previous directory, so that step
            # fails and the main repo's enter hook then sees a stale
            # environment. Run the leave hook explicitly, move to the main
            # repo with the builtin `cd` so that autoenv never sees the dead
            # directory, and then `cd` again so that autoenv runs the main
            # repo's enter hook.
            if [ -f "$main_repo_dir/.autoenv.leave" ]; then
                echo "source $main_repo_dir/.autoenv.leave"
            fi
            echo "builtin cd $main_repo_dir"
        fi
        echo "cd $main_repo_dir"
        ;;
    ls)
        git worktree list
        ;;
    *)
        echo "Error: Unknown subcommand: $subcommand" >&2
        echo >&2
        grep '^#/' "${BASH_SOURCE[0]}" | cut -c4- >&2
        exit 1
        ;;
esac
