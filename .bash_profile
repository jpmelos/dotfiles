# vim: set ft=sh :

# Are we on a Mac?
if [[ "$HOME" =~ /Users/* ]]; then
	JPMELOS_IS_MACOS="true"
else
	JPMELOS_IS_MACOS="false"
fi

#################
#               #
#    Imports    #
#               #
#################

[[ -f ~/.bash_fields.sh ]] && source ~/.bash_fields.sh

##############################
#                            #
#    Environment-specific    #
#                            #
##############################

# Set the PATH. Things are always prepended, so the last entry to be entered
# here is the one with the highest priority.
# Binaries installed by Homebrew.
if [[ $JPMELOS_IS_MACOS == "true" ]]; then
	field_prepend PATH /opt/homebrew/bin
fi
# Binaries not managed via a package manager.
field_prepend PATH "$HOME/.local/bin"
# Neovim's Mason installations.
field_prepend PATH "$HOME/.local/share/nvim/mason/bin"
# Rust tooling's own binaries.
field_prepend PATH "$HOME/.cargo/bin"
# pyenv's own binaries.
field_prepend PATH "$HOME/.pyenv/bin"
# My own executables.
field_prepend PATH "$HOME/bin"
export PATH

#############################
#                           #
#    Bash-specific stuff    #
#                           #
#############################

# How many commands to keep in history.
export HISTSIZE=1000
export HISTFILESIZE=$HISTSIZE
# Erase all duplicate lines, don't store lines starting with space.
export HISTCONTROL=erasedups:ignoreboth
# Persist every command immediately, load new commands.
export PROMPT_COMMAND="history -a; history -n; run_autoenv_on_init; ${PROMPT_COMMAND}"

########################
#                      #
#    Work utilities    #
#                      #
########################

# Sets the default editor for various commands.
export EDITOR=nvim

# Configure ripgrep to use a configuration file.
export RIPGREP_CONFIG_PATH="$HOME/.ripgreprc"

###############################
#                             #
#    Python-specific stuff    #
#                             #
###############################

# Make Pip require a virtual environment to install stuff. Do not pollute
# the system.
export PIP_REQUIRE_VIRTUALENV=true

# No need to show the current virtual environment in the prompt, since we'll
# use Starship for that.
export VIRTUAL_ENV_DISABLE_PROMPT=1

# Indicate where the pyenv root is.
export PYENV_ROOT=$HOME/.pyenv

##########################
#                        #
#    Source ~/.bashrc    #
#                        #
##########################

source ~/.bashrc
