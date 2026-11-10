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
    if [ $# -gt 0 ]; then
        echo "Error: gpsst takes no arguments." >&2
        return 1
    fi
    if ! command -v gh >/dev/null 2>&1; then
        echo "Error: the gh CLI is not installed." >&2
        return 1
    fi
    local tip_branch
    tip_branch="$(git branch --show-current)" || {
        echo "Error: cannot determine current branch." >&2
        return 1
    }
    if [ -z "$tip_branch" ]; then
        echo "Error: not on a branch." >&2
        return 1
    fi
    local main_branch
    main_branch="$(git main-branch)" || {
        echo "Error: cannot determine main branch." >&2
        return 1
    }
    local tip_state
    tip_state="$(gh pr view "$tip_branch" --json state \
        --jq '.state' 2>/dev/null)" || {
        # No observable stack of PRs for the current branch. Push
        # all local branches since the main branch instead. The
        # checks below plus the confirmation keep this safe when
        # the PR lookup failed for another reason. This only pushes
        # branches. It creates no PRs.
        __git_push_new_stack "$tip_branch" "$main_branch"
        return $?
    }
    if [ "$tip_state" != "OPEN" ]; then
        echo "Error: PR for '$tip_branch' is not open." >&2
        return 1
    fi
    local child_count
    child_count="$(gh pr list --base "$tip_branch" \
        --state open --json number --jq 'length')" || {
        echo "Error: cannot list PRs based on '$tip_branch'." >&2
        return 1
    }
    if [ "$child_count" != "0" ]; then
        echo "Error: '$tip_branch' is not the tip of the stack." >&2
        return 1
    fi
    local -a stack=()
    local current_branch="$tip_branch"
    local base_branch
    local merged_branch
    local base_state
    local depth=0
    while true; do
        stack+=("$current_branch")
        base_branch="$(gh pr view "$current_branch" \
            --json baseRefName --jq '.baseRefName')" || {
            echo "Error: cannot get base of '$current_branch'." >&2
            return 1
        }
        if [ "$base_branch" = "$main_branch" ]; then
            break
        fi
        # Follow the base chain through merged PRs. Merged PRs and their
        # branches basically do not exist from this command's perspective.
        while true; do
            base_state="$(gh pr view "$base_branch" --json state \
                --jq '.state')" || {
                echo "Error: base '$base_branch' has no PR." >&2
                return 1
            }
            if [ "$base_state" = "OPEN" ]; then
                break
            fi
            if [ "$base_state" != "MERGED" ]; then
                echo "Error: base '$base_branch' PR is not open." >&2
                return 1
            fi
            echo "Skipping $base_branch (merged)..."
            merged_branch="$base_branch"
            base_branch="$(gh pr view "$merged_branch" \
                --json baseRefName --jq '.baseRefName')" || {
                echo "Error: cannot get base of merged" \
                    "'$merged_branch'." >&2
                return 1
            }
            depth=$((depth + 1))
            if [ "$depth" -gt 50 ]; then
                echo "Error: stack deeper than 50." >&2
                return 1
            fi
            if [ "$base_branch" = "$main_branch" ]; then
                break
            fi
        done
        if [ "$base_branch" = "$main_branch" ]; then
            break
        fi
        current_branch="$base_branch"
        depth=$((depth + 1))
        if [ "$depth" -gt 50 ]; then
            echo "Error: stack deeper than 50." >&2
            return 1
        fi
    done
    local branch
    for branch in "${stack[@]}"; do
        if ! git rev-parse --verify --quiet \
            "refs/heads/$branch" >/dev/null; then
            echo "Error: branch '$branch' missing locally." >&2
            return 1
        fi
        if ! git merge-base --is-ancestor \
            "$branch" "$tip_branch"; then
            echo "Error: '$branch' not in history of '$tip_branch'." >&2
            return 1
        fi
    done
    local index
    local local_sha
    local remote_sha
    for ((index = ${#stack[@]} - 1; index >= 0; index--)); do
        branch="${stack[$index]}"
        # Skip branches that match the remote.
        local_sha="$(git rev-parse "$branch")" || return 1
        remote_sha="$(git rev-parse --verify --quiet \
            "refs/remotes/origin/$branch" 2>/dev/null || true)"
        if [ -n "$remote_sha" ] && [ "$local_sha" = "$remote_sha" ]; then
            echo "Skipping $branch (unchanged)..."
            continue
        fi
        echo "Pushing $branch..."
        git push --force-with-lease --set-upstream \
            origin "$branch" || return 1
    done
}

__git_push_new_stack() {
    # Push all local branches since the main branch. This only
    # pushes branches. It creates no PRs. The user creates those
    # manually.
    local tip_branch="$1"
    local main_branch="$2"
    if [ "$tip_branch" = "$main_branch" ]; then
        echo "Error: on '$main_branch'. Nothing to push." >&2
        return 1
    fi
    if ! git merge-base --is-ancestor \
        "$main_branch" "$tip_branch" 2>/dev/null; then
        echo "Error: '$tip_branch' holds no commits" \
            "since '$main_branch'." >&2
        return 1
    fi
    git fetch origin --prune || return 1
    # Push candidates are local branches that hold commits since
    # the main branch and are in the history of the current branch.
    # This keeps unrelated branches out of the push.
    local -a stack=()
    local branch
    local branch_list
    branch_list="$(mktemp)" || return 1
    git for-each-ref \
        --format='%(refname:short)' refs/heads \
        > "$branch_list" || {
        rm -f "$branch_list"
        return 1
    }
    while IFS= read -r branch; do
        if [ "$branch" = "$main_branch" ]; then
            continue
        fi
        if ! git merge-base --is-ancestor \
            "$main_branch" "$branch" 2>/dev/null; then
            continue
        fi
        if ! git merge-base --is-ancestor \
            "$branch" "$tip_branch" 2>/dev/null; then
            continue
        fi
        if [ "$(git rev-parse "$branch")" = \
            "$(git rev-parse "$main_branch")" ]; then
            continue
        fi
        stack+=("$branch")
    done < "$branch_list"
    rm -f "$branch_list"
    if [ "${#stack[@]}" -eq 0 ]; then
        echo "Error: no local branches since '$main_branch'." >&2
        return 1
    fi
    # Order bottom first, i.e. fewest commits since main first.
    local ordered
    ordered="$(mktemp)" || return 1
    for branch in "${stack[@]}"; do
        printf '%s\t%s\n' \
            "$(git rev-list --count "$main_branch..$branch")" \
            "$branch"
    done | sort -n -k1,1 | cut -f2- > "$ordered" || {
        rm -f "$ordered"
        return 1
    }
    stack=()
    while IFS= read -r branch; do
        stack+=("$branch")
    done < "$ordered"
    rm -f "$ordered"
    # The stack must be linear. Each branch must hold the branch
    # below it in its history.
    local index
    for ((index = 0; index < ${#stack[@]} - 1; index++)); do
        if ! git merge-base --is-ancestor \
            "${stack[$index]}" "${stack[$index + 1]}"; then
            echo "Error: '${stack[$index]}' is not in the history" \
                "of '${stack[$index + 1]}'." >&2
            echo "Error: branches since '$main_branch'" \
                "do not form a linear stack." >&2
            return 1
        fi
    done
    # Each commit since the main branch must carry at most one
    # branch. More than one branch on a commit is ambiguous.
    local commit
    local count
    for commit in $(git rev-list "$main_branch..$tip_branch"); do
        count="$(git for-each-ref --points-at "$commit" \
            refs/heads | wc -l)"
        if [ "$count" -gt 1 ]; then
            echo "Error: commit '$(git rev-parse --short \
                "$commit")' carries more than one branch:" >&2
            git for-each-ref --points-at "$commit" \
                --format='%(refname:short)' refs/heads >&2
            return 1
        fi
    done
    # No branch to push must already exist on the remote. Pushing
    # over an existing remote branch is never intended here.
    local -a existing=()
    for branch in "${stack[@]}"; do
        if git rev-parse --verify --quiet \
            "refs/remotes/origin/$branch" >/dev/null; then
            existing+=("$branch")
        fi
    done
    if [ "${#existing[@]}" -gt 0 ]; then
        echo "Error: remote branches already exist:" \
            "${existing[*]}." >&2
        echo "Error: push those branches normally instead." >&2
        return 1
    fi
    echo "No stack found for '$tip_branch'."
    echo "Branches to push (bottom first):"
    for branch in "${stack[@]}"; do
        echo "  $branch ($(git log -1 \
            --format='%h %s' "$branch"))"
    done
    read -p "Push ${#stack[@]} branches to origin? [y/N] " -n 1 -r
    echo
    if [ "$REPLY" != "y" ] && [ "$REPLY" != "Y" ]; then
        echo "Aborted."
        return 1
    fi
    for branch in "${stack[@]}"; do
        echo "Pushing $branch..."
        git push --set-upstream origin "$branch" || return 1
    done
}

__git_pull_stack() {
    if [ $# -gt 0 ]; then
        echo "Error: gplst takes no arguments." >&2
        return 1
    fi
    if ! command -v gh >/dev/null 2>&1; then
        echo "Error: the gh CLI is not installed." >&2
        return 1
    fi
    local tip_branch
    tip_branch="$(git branch --show-current)" || {
        echo "Error: cannot determine current branch." >&2
        return 1
    }
    if [ -z "$tip_branch" ]; then
        echo "Error: not on a branch." >&2
        return 1
    fi
    local main_branch
    main_branch="$(git main-branch)" || {
        echo "Error: cannot determine main branch." >&2
        return 1
    }
    local tip_state
    tip_state="$(gh pr view "$tip_branch" --json state \
        --jq '.state')" || {
        echo "Error: no PR found for '$tip_branch'." >&2
        return 1
    }
    if [ "$tip_state" != "OPEN" ]; then
        echo "Error: PR for '$tip_branch' is not open." >&2
        return 1
    fi
    local child_count
    child_count="$(gh pr list --base "$tip_branch" \
        --state open --json number --jq 'length')" || {
        echo "Error: cannot list PRs based on '$tip_branch'." >&2
        return 1
    }
    if [ "$child_count" != "0" ]; then
        echo "Error: '$tip_branch' is not the tip of the stack." >&2
        return 1
    fi
    local -a stack=()
    local current_branch="$tip_branch"
    local base_branch
    local merged_branch
    local base_state
    local depth=0
    while true; do
        stack+=("$current_branch")
        base_branch="$(gh pr view "$current_branch" \
            --json baseRefName --jq '.baseRefName')" || {
            echo "Error: cannot get base of '$current_branch'." >&2
            return 1
        }
        if [ "$base_branch" = "$main_branch" ]; then
            break
        fi
        # Follow the base chain through merged PRs. Merged PRs and their
        # branches basically do not exist from this command's perspective.
        while true; do
            base_state="$(gh pr view "$base_branch" --json state \
                --jq '.state')" || {
                echo "Error: base '$base_branch' has no PR." >&2
                return 1
            }
            if [ "$base_state" = "OPEN" ]; then
                break
            fi
            if [ "$base_state" != "MERGED" ]; then
                echo "Error: base '$base_branch' PR is not open." >&2
                return 1
            fi
            echo "Skipping $base_branch (merged)..."
            merged_branch="$base_branch"
            base_branch="$(gh pr view "$merged_branch" \
                --json baseRefName --jq '.baseRefName')" || {
                echo "Error: cannot get base of merged" \
                    "'$merged_branch'." >&2
                return 1
            }
            depth=$((depth + 1))
            if [ "$depth" -gt 50 ]; then
                echo "Error: stack deeper than 50." >&2
                return 1
            fi
            if [ "$base_branch" = "$main_branch" ]; then
                break
            fi
        done
        if [ "$base_branch" = "$main_branch" ]; then
            break
        fi
        current_branch="$base_branch"
        depth=$((depth + 1))
        if [ "$depth" -gt 50 ]; then
            echo "Error: stack deeper than 50." >&2
            return 1
        fi
    done
    git fetch origin --prune || return 1
    local branch
    for branch in "${stack[@]}"; do
        if ! git rev-parse --verify --quiet \
            "refs/remotes/origin/$branch" >/dev/null; then
            echo "Error: no remote branch 'origin/$branch'." >&2
            return 1
        fi
    done
    for branch in "${stack[@]}"; do
        if ! git merge-base --is-ancestor \
            "origin/$branch" "origin/$tip_branch"; then
            echo "Error: 'origin/$branch' not in history" \
                "of 'origin/$tip_branch'." >&2
            return 1
        fi
    done
    local index
    local local_sha
    local remote_sha
    for ((index = ${#stack[@]} - 1; index >= 0; index--)); do
        branch="${stack[$index]}"
        remote_sha="$(git rev-parse --verify --quiet \
            "refs/remotes/origin/$branch" 2>/dev/null || true)"
        if [ -z "$remote_sha" ]; then
            echo "Error: no remote branch 'origin/$branch'." >&2
            return 1
        fi
        if ! git rev-parse --verify --quiet \
            "refs/heads/$branch" >/dev/null; then
            echo "Creating $branch from origin/$branch..."
            git branch --track "$branch" \
                "origin/$branch" || return 1
            continue
        fi
        local_sha="$(git rev-parse "$branch")" || return 1
        if [ "$local_sha" = "$remote_sha" ]; then
            echo "Skipping $branch (unchanged)..."
            continue
        fi
        if git merge-base --is-ancestor \
            "$remote_sha" "$local_sha"; then
            echo "Skipping $branch (local ahead)..."
            continue
        fi
        if ! git merge-base --is-ancestor \
            "$local_sha" "$remote_sha"; then
            echo "Overriding $branch (diverged)..."
            if [ "$branch" = "$tip_branch" ]; then
                git reset --hard "origin/$branch" || return 1
            else
                git update-ref "refs/heads/$branch" \
                    "$remote_sha" || return 1
            fi
            continue
        fi
        echo "Updating $branch..."
        if [ "$branch" = "$tip_branch" ]; then
            git merge --ff-only "origin/$branch" || return 1
        else
            git update-ref "refs/heads/$branch" \
                "$remote_sha" "$local_sha" || return 1
        fi
    done
}

__git_rebase_merge_base() {
    if [ $# -gt 0 ]; then
        echo "Error: grbicm takes no arguments." >&2
        return 1
    fi
    local main_branch
    main_branch="$(git main-branch)" || {
        echo "Error: cannot determine main branch." >&2
        return 1
    }
    # The base of the stack is the common ancestor of
    # the main branch and the current branch.
    local base
    base="$(git merge-base HEAD "$main_branch")" || {
        echo "Error: cannot find merge base with" \
            "'$main_branch'." >&2
        return 1
    }
    local head
    head="$(git rev-parse HEAD)" || return 1
    if [ "$base" = "$head" ]; then
        echo "Error: branch holds no own commits." >&2
        return 1
    fi
    git rebase -i "$base"
}
