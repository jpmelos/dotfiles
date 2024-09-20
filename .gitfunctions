# vim: set ft=sh :

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
