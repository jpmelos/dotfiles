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

__git_stack_branches() {
    # Print stack branches in bottom-first order, one per line.
    # Args are main branch name, main remote ref, and top branch name.
    local main_branch="$1"
    local main_remote="$2"
    local top_branch="$3"

    # Find the fork point between the remote and the top branch.
    # The remote sometimes sits ahead of the stack.
    local stack_base
    stack_base="$(git merge-base "${main_remote}" "${top_branch}")" || return 1

    local rev_list
    rev_list="$(git rev-list --topo-order --reverse \
        "${stack_base}..${top_branch}")" || return 1

    # True when the local main branch exists.
    local have_main=""
    if git show-ref --verify --quiet "refs/heads/${main_branch}"; then
        have_main="yes"
    fi

    # Collect stack branches in bottom-first order.
    # Branch names hold no whitespace, so a for loop is safe.
    local stack_entries=()
    local branch_name
    for branch_name in $(git for-each-ref \
        --format='%(refname:short)' refs/heads); do
        [ "${branch_name}" = "${main_branch}" ] && continue
        # Skip branches already merged upstream.
        if git merge-base --is-ancestor \
            "${branch_name}" "${main_remote}" 2> /dev/null; then
            continue
        fi
        # Skip branches already merged into the local main branch.
        if [ -n "${have_main}" ]; then
            if git merge-base --is-ancestor \
                "${branch_name}" "${main_branch}" 2> /dev/null; then
                continue
            fi
        fi
        # Keep branches between the fork point and the top branch.
        if ! git merge-base --is-ancestor \
            "${stack_base}" "${branch_name}" 2> /dev/null; then
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
    done

    if [ "${#stack_entries[@]}" -eq 0 ]; then
        return 1
    fi

    printf '%s\n' "${stack_entries[@]}" | sort -n -t: -k1,1 | cut -d: -f2-
}

__git_stack_pr_url() {
    # Print PR URL for a branch.
    # Fail when the branch has no PR.
    local branch_name="$1"
    command -v gh > /dev/null 2>&1 || return 1
    gh pr view "${branch_name}" --json url --jq .url 2> /dev/null
}

__git_stack_pr_title() {
    # Print PR title for a branch.
    # Fail when the branch has no PR.
    local branch_name="$1"
    command -v gh > /dev/null 2>&1 || return 1
    gh pr view "${branch_name}" --json title --jq .title 2> /dev/null
}

__git_push_stack() {
    # Parse the mode flag and the optional top branch.
    # With no branch arg, the current branch is the top of the stack.
    local on_latest=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --on-latest)
                on_latest="yes"
                shift
                ;;
            --)
                shift
                break
                ;;
            -*)
                echo "Usage: git psst [--on-latest] [<top-branch>]" >&2
                return 1
                ;;
            *)
                break
                ;;
        esac
    done

    if [ $# -gt 1 ]; then
        echo "Usage: git psst [--on-latest] [<top-branch>]" >&2
        return 1
    fi

    local top_branch=""
    local used_default=""
    if [ $# -eq 1 ]; then
        top_branch="$1"
    else
        used_default="yes"
        top_branch="$(git branch --show-current)" || return 1
        if [ -z "${top_branch}" ]; then
            echo "Error: You gave no branch name and HEAD is detached." >&2
            echo "Error: Pass a branch name. Or checkout a branch first." >&2
            return 1
        fi
    fi

    if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        echo "Error: Not inside a Git repository." >&2
        return 1
    fi

    if ! git show-ref --verify --quiet "refs/heads/${top_branch}"; then
        echo "Error: No local branch '${top_branch}'." >&2
        return 1
    fi

    # Rebase needs a clean working tree.
    # Untracked files do not count.
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "Error: Working tree has uncommitted changes." >&2
        echo "Error: Commit them first. Or stash them first." >&2
        return 1
    fi

    local main_branch
    main_branch="$(git main-branch)" || return 1

    # Fall back to origin when the local main branch has no upstream.
    local main_remote
    if ! main_remote="$(git main-branch-remote 2> /dev/null)"; then
        main_remote="origin/${main_branch}"
    fi

    if ! git rev-parse --verify --quiet "${main_remote}" > /dev/null; then
        echo "Error: Remote ref '${main_remote}' is missing locally." >&2
        echo "Error: Fetch first. Then run again." >&2
        return 1
    fi

    # Find the fork point for display in the plan.
    local plan_base=""
    plan_base="$(git merge-base "${main_remote}" "${top_branch}" \
        2> /dev/null)" || plan_base=""

    # Show plan before any state change.
    # Ask for approval before the rebase steps.
    echo "Stack push plan for top branch '${top_branch}':"
    if [ -n "${used_default}" ]; then
        echo "  Top branch defaults to the current branch."
    fi
    echo "  Base: ${main_remote} (local main: ${main_branch})"
    if [ -n "${plan_base}" ]; then
        local subject=""
        subject="$(git log -1 --format=%s "${plan_base}")"
        echo "  Fork: $(git rev-parse --short "${plan_base}") (${subject})"
    fi
    if [ -n "${on_latest}" ]; then
        echo "  Steps: fetch, checkout ${top_branch}," \
            "rebase onto ${main_remote}."
    else
        echo "  Steps: checkout ${top_branch}, rebase onto the fork point."
    fi
    echo ""

    local reply=""
    read -p "Proceed with the steps above? [y/N] " -n 1 -r reply
    echo ""
    if [[ ! "${reply}" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        return 1
    fi

    # Fetch runs only after approval, so the rebase uses fresh state.
    # Fork mode fetches nothing and uses local refs only.
    local rebase_target=""
    if [ -n "${on_latest}" ]; then
        git fetch --all || return 1
        rebase_target="${main_remote}"
    else
        if ! rebase_target="$(git merge-base "${main_remote}" \
            "${top_branch}" 2> /dev/null)"; then
            echo "Error: No fork point found between '${main_remote}'" \
                "and '${top_branch}'." >&2
            return 1
        fi
    fi

    # Skip the rebase when the target already matches the top branch.
    # An empty range gives the editor nothing to replay.
    local target_tip=""
    local top_tip=""
    target_tip="$(git rev-parse "${rebase_target}")" || return 1
    top_tip="$(git rev-parse "${top_branch}")" || return 1
    if [ "${target_tip}" = "${top_tip}" ]; then
        echo "Top branch already sits on the rebase target."
        echo "Skip the rebase."
    else
        git checkout "${top_branch}" || return 1

        # Interactive rebase opens the editor for review.
        # Intermediate branches move with updateRefs from the Git config.
        if ! git rebase -i "${rebase_target}"; then
            echo "Rebase stopped (conflict or abort)." >&2
            echo "Resolve it. Then run again to push." >&2
            return 1
        fi
    fi

    # Collect the push list from the rebased state.
    # Merged branches drop out here.
    # Read push lines through a heredoc.
    # Heredocs need no process substitution.
    # The EOF delimiter stays at column zero, as the shell requires.
    local push_branches=()
    local push_branch_name
    while IFS= read -r push_branch_name; do
        [ -z "${push_branch_name}" ] && continue
        push_branches+=("${push_branch_name}")
    done <<EOF
$(__git_stack_branches "${main_branch}" "${main_remote}" "${top_branch}")
EOF

    if [ "${#push_branches[@]}" -eq 0 ]; then
        echo "No stack branches found for '${top_branch}'."
        return 1
    fi

    # Show push plan before the push.
    # Ask for approval before the push.
    echo ""
    echo "  Branches to push (bottom first):"
    local push_branch
    local index=1
    for push_branch in "${push_branches[@]}"; do
        echo "    ${index}. ${push_branch}"
        local pr_url=""
        local pr_title=""
        if pr_url="$(__git_stack_pr_url "${push_branch}" 2> /dev/null)"; then
            echo "       PR: ${pr_url}"
            pr_title="$(__git_stack_pr_title "${push_branch}" \
                2> /dev/null)" || pr_title=""
            if [ -n "${pr_title}" ]; then
                echo "       Title: ${pr_title}"
            fi
        else
            if ! command -v gh > /dev/null 2>&1; then
                echo "       PR: unknown (gh not available)."
            else
                echo "       PR: none yet."
            fi
            echo "       Push updates the remote branch," \
                "or creates it when absent."
            echo "       It creates no PR."
        fi
        index=$((index + 1))
    done
    echo ""
    echo "It creates no PRs."
    echo "Push updates remote branches, or creates them when absent."
    echo ""

    local push_reply=""
    read -p "Proceed with push? [y/N] " -n 1 -r push_reply
    echo ""
    if [[ ! "${push_reply}" =~ ^[Yy]$ ]]; then
        echo "Aborted."
        return 1
    fi

    # Push bottom-first, with lease for safety after the rebase.
    # Never create PRs here.
    local push_item
    for push_item in "${push_branches[@]}"; do
        echo "Push ${push_item}."
        if ! git push -u --force-with-lease origin "${push_item}"; then
            return 1
        fi
    done
}
