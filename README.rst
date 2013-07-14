dotfiles for Debian configuration
=================================

Clone this repository to your home folder to install configuration.

Install
-------

To install these dotfiles, run the `./dotfiles.sh install` bash script. Check
the output to see what files might need to be verified.

Add line::

	source ~/.mybashrc

to your `~/.bashrc` file to get working bash configuration.

Uninstall
---------

To remove, run `dotfiles.sh uninstall`.

Remove the line::

	source ~/.mybashrc

from your `~/.bashrc` file.

Additional Perks
----------------

Besides `install` and `uninstall`, you can also do:

	- reinstall: Reinstalls the dotfiles. Use with care, will wipe any
	  change you made to the hard copies.
	- pull: Will uninstall, pull the repository, install the submodules and
	  then install.

If you want to update all your `~/devel/` (or any other foder) git repositories
once a day, add this line to your cron. All repositories must have the same
remote name. For example, `github`::

	@daily ~/update_remote.sh ~/devel github
