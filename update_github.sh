#!/usr/bin/env sh

for dir in $1/*; do
	if [ -d "$dir" ]; then
		cd "$dir"
		git push $2 --all
	fi
done
