GIT_LS='git ls-tree --name-only HEAD'

git submodule init
git submodule update

./dot-uninstall.sh

for f in `$GIT_LS`
do
	ln -s `pwd`/$f ~/$f
done
