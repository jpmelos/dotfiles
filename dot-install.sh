GIT_LS='git ls-tree --name-only HEAD'

./dot-uninstall.sh

for f in `$GIT_LS`
do
	ln -s `pwd`/$f ~/$f
done
