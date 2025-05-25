# README

## Installing these dotfiles

1. Clone the Git template directory:

   ```
   mkdir -p ~/devel
   cd ~/devel
   git clone git@github.com:jpmelos/git-template.git
   ```

2. Clone these dotfiles:

   ```
   git clone --template=~/devel/git-template git@github.com:jpmelos/dotfiles.git
   ```

3. Install `stow`.

4. Run:

   ```bash
   cd ~/devel/dotfiles
   stow .
   ```
