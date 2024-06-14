# vim: set ft=sh :

# Set up the GPG Agent.
export GPG_TTY=$(tty)

#############################
#                           #
#    Bash-specific stuff    #
#                           #
#############################

# - histverify: Command history substitutions are put in the input line for
#   verification, instead of being immediately run.
# - no_empty_cmd_completion: When completion is attempted on an empty line
#   (press <Tab> on an empty line), bash won't look in $PATH for completing
#   possible commands.
shopt -s histverify no_empty_cmd_completion

run_autoenv_on_init() {
	if [ -z "$AUTOENV_RAN_ON_INIT" ]; then
		cd /
		cd - >/dev/null
		AUTOENV_RAN_ON_INIT=1
	fi
}

#################
#               #
#    autoenv    #
#               #
#################

# Find authorized and unauthorized autoenvs in these files.
[ -f ~/.autoenv_authorized ] || touch ~/.autoenv_authorized
[ -f ~/.autoenv_not_authorized ] || touch ~/.autoenv_not_authorized
# Enable autoenv leave too.
AUTOENV_ENABLE_LEAVE=1
# Rename autoenv files to less generic names.
AUTOENV_ENV_FILENAME=.autoenv.enter
AUTOENV_ENV_LEAVE_FILENAME=.autoenv.leave

source ~/.autoenv/activate.sh

################
#              #
#    Prompt    #
#              #
################

eval "$(starship init bash)"

###############################
#                             #
#    Python-specific stuff    #
#                             #
###############################

# Set up pyenv for each interactive shell.
eval "$(pyenv init -)"

################################
#                              #
#    Homebrew's completions    #
#                              #
################################

if type brew &>/dev/null; then
	HOMEBREW_PREFIX="$(brew --prefix)"

	for COMPLETION in "${HOMEBREW_PREFIX}/etc/bash_completion.d/"*; do
		[[ -r "${COMPLETION}" ]] && source "${COMPLETION}"
	done
fi

#################
#               #
#    Aliases    #
#               #
#################

# Search history.
alias h="history | grep"
#
# Search running processes.
alias p="ps aux | grep"

# Find out what is taking so much space on your drives!
alias diskspace="du -S | sort -n -r | more"

# Show me the size (sorted) of only the folders in this directory.
alias folders="find . -maxdepth 1 -type d -print | xargs du -sk | sort -rn"

# Edit Bash configuration files.
alias erc='nvim -O ~/.bash_profile ~/.bashrc'

# Source Bash configuration files.
alias src='source ~/.bash_profile'

# Show path in readable format.
alias path='echo $PATH | tr : "\n"'

# Allows alias checking in watch commands.
alias watch='watch '

# Makes Neovim open multiple files in different buffers, all immediately
# visible, in the same tab.
alias v='\nvim -O'
alias vi='\nvim -O'
alias vim='\nvim -O'
alias nvim='\nvim -O'

# Ask before destructive actions.
alias cp='cp -i'
alias mv='mv -i'

# Docker aliases.
alias d='docker'
alias dc='docker-compose'
alias docker-nuke-all-the-things='yes | docker system prune --volumes --all'

# Git aliases.
# When adding an alias, also configure completions below.
alias g='git'
alias gb='g b'
alias gbn='g bn'
alias gbd='g bd'
alias gco='g co'
alias gcm='g cm'
alias gcp='g cp'
alias gst='g st'
alias gd='g d'
alias gdst='g dst'
alias gdca='g dca'
alias ga='g a'
alias gaa='g aa'
alias gapa='g apa'
alias gc='g c'
alias gca='g ca'
alias gsh='g sh'
alias gshf='g shf'
alias gshh='g shh'
alias gp='g p'
alias gpf='g pf'
alias gl='g l'

#########################
#                       #
#    git completions    #
#                       #
#########################

__git_complete g git
__git_complete gb git_branch
__git_complete gbn git_checkout
__git_complete gbd git_branch
__git_complete gco git_checkout
__git_complete gcm git_checkout
__git_complete gst git_status
__git_complete gd git_diff
__git_complete gdca git_diff
__git_complete ga git_add
__git_complete gaa git_add
__git_complete gapa git_add
__git_complete gc git_commit
__git_complete gca git_commit
__git_complete gsh git_show
__git_complete gshf git_show
__git_complete gshh git_show
__git_complete gp git_push
__git_complete gpsup git_push
__git_complete gpf git_push
__git_complete gl git_log

###################
#                 #
#    Functions    #
#                 #
###################

# Updates the system.
update() {
	sudo apt-get --allow-releaseinfo-change update
	sudo apt-get -y --allow-downgrades dist-upgrade
	sudo apt-get -y autoremove
	sudo apt-get -y clean
}

# Extract stuff.
extract() {
	if [ -f "$1" ]; then
		case "$1" in
		*.tar.bz2) tar xjf "$1" ;;
		*.tar.gz) tar xzf "$1" ;;
		*.bz2) bunzip2 "$1" ;;
		*.rar) rar x "$1" ;;
		*.gz) gunzip "$1" ;;
		*.tar) tar xf "$1" ;;
		*.tbz2) tar xjf "$1" ;;
		*.tgz) tar xzf "$1" ;;
		*.zip) unzip "$1" ;;
		*.Z) uncompress "$1" ;;
		*.7z) 7z x "$1" ;;
		*) echo "'$1' cannot be extracted via extract()" ;;
		esac
	else
		echo "'$1' is not a valid file"
	fi
}

######################
#                    #
#    Go into tmux    #
#                    #
######################

if [ -z "$TMUX" ]; then
	if tmux has-session; then
		exec tmux attach
	else
		exec tmux
	fi
fi
