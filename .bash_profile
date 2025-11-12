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
# Rust tooling's own binaries.
field_prepend PATH "$HOME/.cargo/bin"
# pyenv's own binaries.
field_prepend PATH "$HOME/.pyenv/bin"
# My own executables.
field_prepend PATH "$HOME/bin"
export PATH

################################
#                              #
#    Terminal configuration    #
#                              #
################################

export TERMINFO_DIRS=$HOME/.local/share/terminfo:$TERMINFO_DIRS

#############################
#                           #
#    Bash-specific stuff    #
#                           #
#############################

# How many commands to keep in history.
export HISTSIZE=100000
export HISTFILESIZE=$HISTSIZE
# Erase all duplicate lines, don't store lines starting with space.
export HISTCONTROL=erasedups:ignoreboth

# Function to reset the terminal title.
BASH_TERMINAL_TITLE="bash"
function reset_terminal_title() {
    echo -ne "\033]0;$BASH_TERMINAL_TITLE\007"
}

# Persist every command immediately, load new commands.
export PROMPT_COMMAND="history -a; history -n; run_autoenv_on_init; reset_terminal_title; ${PROMPT_COMMAND}"

########################
#                      #
#    Work utilities    #
#                      #
########################

# Sets the default pager for various commands. Useful when working with tools
# like `psql` which can have large outputs that are more easily viewed in a
# larger canvas than the usual terminal size.
export PAGER="less -S"

# Sets the default editor for various commands.
export EDITOR="nvim"

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

#########################
#                       #
#    Other utilities    #
#                       #
#########################

export OP_ACCOUNT=my.1password.com

##########################
#                        #
#    Source ~/.bashrc    #
#                        #
##########################

source ~/.bashrc
