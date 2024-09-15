# README

## Installing these dotfiles

1. Install `stow`.

1. Run:

   ```bash
   stow .
   ```

## Installing tmux plugins

1. Install `tpm`, the tmux plugin manager.

   ```bash
   git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
   ```

1. Type `<prefix>I`.

## [MacOS only] Configuring terminal for font effects and more

1. Install the latest version of `ncurses`.

1. Set the correct terminfo in your `.bash_profile` file:

   ```bash
   # Find any custom terminfos that we install.
   export TERMINFO_DIRS=$HOME/.local/share/terminfo:$TERMINFO_DIRS
   # For better colors in Neovim.
   export TERM=tmux-256color
   ```

1. Set the correct terminfo in your `tmux.conf` file as well:

   ```
   set -s default-terminal tmux-256color
   ```

1. Copy the `tmux-256color` terminfo from the newer Homebrew to a file:

   ```bash
   /opt/homebrew/opt/ncurses/bin/infocmp -x tmux-256color > ~/tmux-256color.src
   ```

1. Modify `~/tmux-256color.src` to change `pairs` from 65,536 to 32,767. You
   should look in `~/tmux-256color.src` for `pairs`, and change either
   `pairs#0x1000` or `pairs#65536` to `pairs#32767`.

1. Finally, install this new terminfo somewhere where the system can find it.
   That's why we changed `TERMINFO_DIRS` in `bash_profile` above:

   ```bash
   /usr/bin/tic -x -o $HOME/.local/share/terminfo tmux-256color.src
   ```

   Be sure to use `/usr/bin/tic` instead of just `tic` to use the system-wide
   one.
