# Only copy files in the repository, and from the first level, since we are
# creating links. All files in lower levels can be accessed through the links
# to their parents.
FILES_TO_COPY='git ls-tree --name-only HEAD'

# These files will have a hard copy instead of a link, because their contents
# might differ. They might store passwords, for example, which we do not want
# to propagate upstream.
HARD_COPY=.irssi

function uninstall {
	for f in `$FILES_TO_COPY`
	do
		rm -rf ~/$f
	done
}

function install {
	uninstall

	echo "Files to verifiy (these had a hard copy):"

	for f in `$FILES_TO_COPY`
	do
		if [[ "$HARD_COPY" == *"$f"* ]]; then
			cp -R $f ~/$f
			echo $f
		else
			ln -s `pwd`/$f ~/$f
		fi
	done
}

# Arguments: $2 = remote repository, $3 = remote branch
function pull {
	uninstall
	git pull $2 $3
	git submodule init
	git submodule update
	install
}

case $1 in
	"install" )
		install ;;
	"uninstall" )
		uninstall ;;
	"pull" )
		pull ;;
esac
