#!/bin/bash

# Check if we are inside a Git repository
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
    echo "Error: Not inside a Git repository."
    exit 1
fi

# Check if refs/remotes/origin/HEAD is a symbolic ref.
# git symbolic-ref will exit with nonzero status if it's not symbolic.
if ! git symbolic-ref refs/remotes/origin/HEAD &> /dev/null; then
    echo "refs/remotes/origin/HEAD is not a symbolic ref. Running 'git remote set-head origin --auto'..."
    if git remote set-head origin --auto &> /dev/null; then
        echo "Remote HEAD has been updated automatically."
    else
        echo "Error updating remote HEAD."
        exit 1
    fi
fi
