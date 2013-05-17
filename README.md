dotfiles for Ubuntu configuration
=================================

Clone this repository to your home folder to install configuration.

Add line

	source ~/.mybashrc

to your `~/.bashrc` file to get working bash configuration.

If you want to update all your `~/devel/` git repositories once a day, add this
line to your cron. All repositories must have the same remote name. For
example, `github`.

	@daily ~/update_remote.sh ~/devel <remote name>
