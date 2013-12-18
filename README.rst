dotfiles for Debian configuration
=================================

Clone this repository to your home folder to install configuration.

Install
-------

To install these dotfiles, run the ``./dotfiles.sh install`` bash script. Check
the output to see what files might need to be verified.

Add line::

	source ~/.mybashrc

to your `~/.bashrc` file and add the line::

	source ~/.myprofile

to your `~/.profile` to get working bash configuration.

Uninstall
---------

To remove, run ``dotfiles.sh uninstall``.

Remove the line::

	source ~/.mybashrc

from your `~/.bashrc` file and the line::

    source ~/.myprofile

from your `~/.profile` file.

Additional Perks
----------------

Besides ``install`` and ``uninstall``, you can also ``pull``, which will
uninstall, pull the repository, install the submodules and then install the
dotfiles.

If you want to upload all your ``~/devel/`` (or any other foder) git
repositories once a day (in case you wish to keep some upstream updated), add
this line to your cron. All repositories must have the same remote name. For
example, ``github``::

	@daily ~/update_remote.sh ~/devel github
