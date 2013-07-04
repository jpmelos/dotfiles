dotfiles for Debian configuration
=================================

Clone this repository to your home folder to install configuration.

Install
-------

To install these dotfiles, run the `dot-install.sh` bash script.

Add line

	source ~/.mybashrc

to your `~/.bashrc` file to get working bash configuration.

Uninstall
---------

To remove, run `dot-uninstall.sh`.

Remove the line 

	source ~/.mybashrc

from your `~/.bashrc` file.

Additional Perks
----------------

If you want to update all your `~/devel/` git repositories once a day, add this
line to your cron. All repositories must have the same remote name. For
example, `github`.

	@daily ~/update_remote.sh ~/devel <remote name>
