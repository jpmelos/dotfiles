__git_nuke() {
    git checkout -f "$(git main-branch)"
    git reset --hard "origin/$(git main-branch)"
    git fetch --prune
    for branch in $(git branch -vv | grep ': gone]' | awk '{print $1}'); do
        git branch -D "$branch"
    done
    git gc --prune=now --aggressive
    git prune
}

__git_big_revert() {
    git diff-index --quiet HEAD || {
        echo "Not clean"
        exit 1
    }

    ts=$(date +"%Y%m%dT%H%M%S")
    tmp_branch="_make-a-big-revert-to-$ts"

    git branch "${tmp_branch}"
    git reset --hard "$1"
    git submodule update --init --recursive
    git reset "$tmp_branch"
    git branch -D "$tmp_branch"
    shift
    git commit -a --no-verify "$@"
}

__git_push_stack() {
    if [ $# -ne 1 ]; then
        echo "Usage: git psst <top-branch>" >&2
        return 1
    fi

    local top_branch="$1"

    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        echo "Error: Not inside a Git repository." >&2
        return 1
    fi

    if ! git show-ref --verify --quiet "refs/heads/${top_branch}"; then
        echo "Error: No local branch '${top_branch}'." >&2
        return 1
    fi

    # Rebase requires a clean working tree, ignoring untracked files.
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "Error: Working tree has uncommitted changes." \
            "Commit or stash them first." >&2
        return 1
    fi

    # Fetch first, so the rebase uses the latest remote state.
    git fetch --all || return 1

    local main_branch
    main_branch="$(git main-branch)" || return 1

    # Fall back to origin when the local main branch has no upstream.
    local main_remote
    if ! main_remote="$(git main-branch-remote 2> /dev/null)"; then
        main_remote="origin/${main_branch}"
    fi

    git checkout "${top_branch}" || return 1

    # Interactive rebase, so the editor opens for review.
    # Intermediate branches move with updateRefs from the Git config.
    if ! git rebase -i "${main_remote}"; then
        echo "Rebase stopped (conflict or abort)." \
            "Resolve it, then run again to push." >&2
        return 1
    fi

    local rev_list
    rev_list="$(git rev-list --topo-order --reverse \
        "${main_remote}..${top_branch}")" || return 1

    # Collect stack branches in bottom-first order.
    local stack_entries=()
    local branch_name
    while IFS= read -r branch_name; do
        [ "${branch_name}" = "${main_branch}" ] && continue
        if ! git merge-base --is-ancestor \
            "${main_remote}" "${branch_name}" 2> /dev/null; then
            continue
        fi
        if ! git merge-base --is-ancestor \
            "${branch_name}" "${top_branch}" 2> /dev/null; then
            continue
        fi
        local tip_sha
        tip_sha="$(git rev-parse "${branch_name}")" || continue
        local line_number
        line_number="$(printf '%s\n' "${rev_list}" | \
            grep -n -x "${tip_sha}" | cut -d: -f1)"
        [ -z "${line_number}" ] && continue
        stack_entries+=("${line_number}:${branch_name}")
    done < <(git for-each-ref --format='%(refname:short)' refs/heads)

    if [ "${#stack_entries[@]}" -eq 0 ]; then
        echo "No stack branches found for '${top_branch}'."
        return 1
    fi

    # Push bottom-first, with lease for safety after the rebase.
    local sorted_entry
    while IFS= read -r sorted_entry; do
        local push_branch="${sorted_entry#*:}"
        echo "Pushing ${push_branch}..."
        if ! git push -u --force-with-lease origin "${push_branch}"; then
            return 1
        fi
    done < <(printf '%s\n' "${stack_entries[@]}" | sort -n -t: -k1,1)
}
