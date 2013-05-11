#!/usr/bin/env sh

for dir in $1/*git; do
	if [ -d "$dir" ]; then
		echo "Updating $dir"
		cd "$dir"
		git push $2 --all
	fi
done
