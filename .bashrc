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
        cd - > /dev/null
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

if type brew &> /dev/null; then
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

# Always ignore the .git directory.
alias tree='tree -I ''.git'''

# Docker aliases.
alias d='docker'
alias dc='docker compose'
alias docker-nuke-all-the-things='docker rm -f $(docker ps -aq); yes | docker system prune --volumes --all'

# Adjust `act` according to the environment.
if [ "$JPMELOS_IS_MACOS" = "true" ]; then
    alias act="act --container-architecture linux/amd64"
fi

#####################################
#                                   #
#    git aliases and completions    #
#                                   #
#####################################

alias g='git'
__git_complete g git

alias gnuke='g nuke'

alias gst='g st'
__git_complete gst git_status

alias gsh='g sh'
alias gshf='g shf'
alias gshh='g shh'
__git_complete gsh git_show
__git_complete gshf git_show
__git_complete gshh git_show

alias gl='g l'
alias glf='g lf'
__git_complete gl git_log
__git_complete glf git_log

alias gls='g ls'
__git_complete gls git_ls_tree

alias gb='g b'
alias gbr='g br'
alias gbn='g bn'
alias gbd='g bd'
__git_complete gb git_branch
__git_complete gbr git_branch
__git_complete gbn git_checkout
__git_complete gbd git_branch

alias gd='g d'
alias gdst='g dst'
alias gdca='g dca'
alias gdm='g dm'
__git_complete gd git_diff
__git_complete gdst git_diff
__git_complete gdca git_diff
__git_complete gdm git_diff

alias go='g o'
alias gom='g om'
alias gof='g of'
__git_complete go git_checkout
__git_complete gom git_checkout
__git_complete gof git_checkout

alias ga='g a'
alias gaa='g aa'
alias gapa='g apa'
__git_complete ga git_add
__git_complete gaa git_add
__git_complete gapa git_add

alias gc='g c'
alias gca='g ca'
alias gcm='g cm'
alias gcn='g cn'
alias gcam='g cam'
alias gcan='g can'
alias gcmn='g cmn'
alias gcamn='g camn'
alias gcw='g cw'
alias gucw='g ucw'
__git_complete gc git_commit
__git_complete gca git_commit
__git_complete gcm git_commit
__git_complete gcn git_commit
__git_complete gcam git_commit
__git_complete gcan git_commit
__git_complete gcmn git_commit
__git_complete gcamn git_commit
__git_complete gcw git_commit
__git_complete gucw git_reset

alias gcp='g cp'
__git_complete gcp git_cherry_pick

alias gr='g r'
alias grm='g rbm'
alias gri='g ri'
alias grim='g rim'
alias grc='g rc'
alias gra='g ra'
__git_complete gr git_rebase
__git_complete grm git_rebase
__git_complete gri git_rebase
__git_complete grim git_rebase
__git_complete grc git_rebase
__git_complete gra git_rebase

alias gp='g p'
alias gpf='g pf'
__git_complete gp git_push
__git_complete gpf git_push

alias gpu='g pu'
__git_complete gpu git_pull

###################
#                 #
#    Functions    #
#                 #
###################

# Find current default interface.
if [ "$JPMELOS_IS_MACOS" = "true" ]; then
    default_if() {
        route -n get default | grep 'interface:' | awk '{print $2}'
    }
else
    default_if() {
        echo "Implement for Linux..."
    }
fi

# Find the IP of the interface to the default gateway.
if [ "$JPMELOS_IS_MACOS" = "true" ]; then
    default_if_ip() {
        ifconfig "$(default_if)" | grep 'inet ' | awk '{print $2}'
    }
else
    default_if_ip() {
        echo "Implement for Linux..."
    }
fi

# Updates the system.
if [ "$JPMELOS_IS_MACOS" = "true" ]; then
    update() {
        brew update && brew upgrade
    }
else
    update() {
        sudo apt-get --allow-releaseinfo-change update
        sudo apt-get -y --allow-downgrades dist-upgrade
        sudo apt-get -y autoremove
        sudo apt-get -y clean
    }
fi

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
    if du -b /dev/null > /dev/null 2>&1; then
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
    local addr="${1:-0.0.0.0}"
    local port="${2:-8000}"

    sleep 2 && open "http://$addr:$port/" &
    python3 -m http.server "$port" -b "$addr"
}

# Compare original and gzipped file size.
function gz() {
    local origsize=$(wc -c < "$1")
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

function is_in_path() {
    builtin type -P "$1" &> /dev/null
}

function cm() {
    current_dir="$(pwd)"
    devel_dir="$HOME/devel"

    if [[ "$current_dir" == "$devel_dir"* ]]; then
        project_relative_path="${current_dir#$devel_dir/}"
    else
        echo "Error: not inside ~/devel" >&2
        return
    fi

    profile="$1"
    if [ -z "$profile" ]; then
        first_component=$(echo "$project_relative_path" | cut -d'/' -f1)
        if [ -d "$HOME/.claude-manager/profiles/$first_component" ]; then
            profile="$first_component"
        else
            profile="jpmelos"
        fi
    fi

    profile_dir="$HOME/.claude-manager/profiles/$profile"
    profile_claude_dir="$profile_dir/.claude"
    profile_json="$profile_dir/.claude.json"

    mkdir -p "$profile_claude_dir"
    if [ ! -f "$profile_json" ]; then
        echo "{}" > "$profile_json"
    fi

    project_name="$(echo $project_relative_path | sed 's|/|--|g')"
    claude_manager_home="/home/user"

    docker build \
        --build-arg TODAY=$(date +%Y-%m-%d) \
        -t claude-manager \
        ~/devel/dotfiles/claude-manager/

    docker run --rm -ti \
        --name "claude-code-$project_name" \
        --user $(id -u):$(id -g) \
        -e TERM="$TERM" \
        -v "$profile_json:$claude_manager_home/.claude.json" \
        -v "$profile_claude_dir:$claude_manager_home/.claude" \
        -v "$(pwd):$claude_manager_home/workspace/$project_name" \
        claude-manager
}
