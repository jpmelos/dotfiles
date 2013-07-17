#!/usr/bin/env sh

for dir in $1/[[:lower:]]*.git; do
	if [ -d "$dir" ]; then
		echo "Updating $dir"
		cd "$dir"
		git push -f --all $2
		git push -f --tags $2
	fi
done
