#!/usr/bin/env sh

for dir in $1/*git; do
	if [ -d "$dir" ]; then
		echo "Updating $dir"
		cd "$dir"
		git push --all --tags $2
	fi
done
