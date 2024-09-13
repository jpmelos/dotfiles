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
alias dc='docker compose'
alias docker-nuke-all-the-things='yes | docker system prune --volumes --all'

#####################
#                   #
#    git aliases    #
#                   #
#####################
# When adding an alias, also configure completions below.

alias g='git'

alias gb='g b'
alias gbn='g bn'
alias gbd='g bd'

alias go='g o'
alias gom='g om'

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
alias gcm='g cm'
alias gcn='g cn'
alias gcma='g cma'
alias gcan='g can'
alias gcmn='g cmn'
alias gcman='g cman'

alias gsh='g sh'
alias gshf='g shf'
alias gshh='g shh'

alias gp='g p'
alias gpf='g pf'

alias gl='g l'

alias gnuke='g nuke'

#########################
#                       #
#    git completions    #
#                       #
#########################

__git_complete g git

__git_complete gb git_branch
__git_complete gbn git_checkout
__git_complete gbd git_branch

__git_complete go git_checkout
__git_complete gom git_checkout

__git_complete gcp git_cherry_pick

__git_complete gst git_status

__git_complete gd git_diff
__git_complete gdst git_diff
__git_complete gdca git_diff

__git_complete ga git_add
__git_complete gaa git_add
__git_complete gapa git_add

__git_complete gc git_commit
__git_complete gca git_commit
__git_complete gcm git_commit
__git_complete gcn git_commit
__git_complete gcma git_commit
__git_complete gcan git_commit
__git_complete gcmn git_commit
__git_complete gcman git_commit

__git_complete gsh git_show
__git_complete gshf git_show
__git_complete gshh git_show

__git_complete gp git_push
__git_complete gpf git_push

__git_complete gl git_log

###################
#                 #
#    Functions    #
#                 #
###################

gnh() { # git no hooks
    echo "Disabling git hooks..."
    mv "$(git root)/.git/hooks" "$(git root)/.git/hooks_dead"
    eval $*
    mv "$(git root)/.git/hooks_dead" "$(git root)/.git/hooks"
    echo "Re-enabled git hooks."
}

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

# Determine actual size of a file in disk (considers entire blocks) or total
# size of a directory.
function fs() {
    if du -b /dev/null >/dev/null 2>&1; then
        local arg=-sbh
    else
        local arg=-sh
    fi
    if [[ -n "$@" ]]; then
        du $arg -- "$@"
    else
        du $arg .[^.]* ./*
    fi
}

# Start an HTTP server from a directory, optionally specifying the port
function server() {
    local port="${1:-8000}"
    sleep 1 && open "http://localhost:${port}/" &
    # Set the default Content-Type to `text/plain` instead of
    # `application/octet-stream` snd serve everything as UTF-8 (although not
    # technically correct, this doesn’t break anything for binary files).
    python -c $'import SimpleHTTPServer;\nmap = SimpleHTTPServer.SimpleHTTPRequestHandler.extensions_map;\nmap[""] = "text/plain";\nfor key, value in map.items():\n\tmap[key] = value + ";charset=UTF-8";\nSimpleHTTPServer.test();' "$port"
}

# Compare original and gzipped file size.
function gz() {
    local origsize=$(wc -c <"$1")
    local gzipsize=$(gzip -c "$1" | wc -c)
    local ratio=$(echo "$gzipsize * 100 / $origsize" | bc -l)
    printf "orig: %d bytes\n" "$origsize"
    printf "gzip: %d bytes (%2.2f%%)\n" "$gzipsize" "$ratio"
}

# Normalize `open` across Linux, macOS, and Windows.
# This is needed to make the `o` function (see below) cross-platform.
if [ ! $(uname -s) = 'Darwin' ]; then
    if grep -q Microsoft /proc/version; then
        # Ubuntu on Windows using the Linux subsystem
        alias open='explorer.exe'
    else
        alias open='xdg-open'
    fi
fi

# `o` with no arguments opens the current directory, otherwise opens the given
# location.
function o() {
    if [ $# -eq 0 ]; then
        open .
    else
        open "$@"
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
