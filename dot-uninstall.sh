GIT_LS='git ls-tree --name-only HEAD'

for f in `$GIT_LS`
do
	rm ~/$f
done
