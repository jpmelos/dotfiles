# README

## Installing tmux

1. Install the plugin manager.

   ```bash
   git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
   ```

1. Link `dotfiles/tmux.conf` to `~/.tmux.conf`.

1. Run `<C-a> I`.

## Installing nvim

1. Link `dotfiles/nvim` to `~/.config/nvim`.

## tmux-256color in MacOS (not needed in latest versions)

1. Install a newer version of `ncurses` with Homebrew:

   ```bash
   brew install ncurses
   ```

1. Set the correct terminfo in your bash files:

   ```bash
   # Find any custom terminfos that we install.
   export TERMINFO_DIRS=$HOME/.local/share/terminfo:$TERMINFO_DIRS
   # For better colors in Neovim.
   export TERM=tmux-256color
   ```

1. Set the correct terminfo in your `tmux.conf` file as well:

   ```bash
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
