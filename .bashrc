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

################
#              #
#    Prompt    #
#              #
################

run_autoenv_on_init() {
    if [ -z "$AUTOENV_RAN_ON_INIT" ]; then
        cd /
        cd - > /dev/null
        AUTOENV_RAN_ON_INIT=1
    fi
}

BASH_TERMINAL_TITLE="bash"
reset_terminal_title() {
    echo -ne "\033]0;$BASH_TERMINAL_TITLE\007"
}

if [[ "$PROMPT_COMMAND" != *"reset_terminal_title"* ]]; then
    export PROMPT_COMMAND="history -a; history -n; run_autoenv_on_init; reset_terminal_title; ${PROMPT_COMMAND}"
fi

eval "$(starship init bash)"

#################
#               #
#    autoenv    #
#               #
#################

# Find authorized and unauthorized autoenvs in these files.
[ -f ~/.autoenv_authorized ] || touch ~/.autoenv_authorized
[ -f ~/.autoenv_not_authorized ] || touch ~/.autoenv_not_authorized

# The variables below don't need to be exported because we're sourcing the
# autoenv activation script.
# Enable autoenv leave too.
AUTOENV_ENABLE_LEAVE=1
# Rename autoenv files to less generic names.
AUTOENV_ENV_FILENAME=.autoenv.enter
AUTOENV_ENV_LEAVE_FILENAME=.autoenv.leave

source ~/.autoenv/activate.sh

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

# List current directory with details.
alias l='ls -FhAls'

# Search history.
alias h="history | grep"

# Copy and paste shortcuts.
# Strictly, c is not an alias, but it's just a very thin wrapper around
# `pbcopy` to make it trim leading and trailing whitespaces from the input.
c() {
    perl -0777 -pe 's/^\s+|\s+$//g' | pbcopy
}
alias p="pbpaste"

# Find out what is taking so much space on your drives!
alias diskspace="du -S | sort -n -r | more"

# Show me the size (sorted) of only the folders in this directory.
alias folders="find . -maxdepth 1 -type d -print | xargs du -sk | sort -rn"

# Edit Bash configuration files.
alias erc='nvim -O ~/.bash_profile ~/.bashrc'

# Source Bash configuration files.
alias src='source ~/.bash_profile'

# Show path in readable format.
alias path='tr : "\n" <<< "$PATH"'

# Allows alias checking in watch commands.
alias watch='\watch '

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
alias tree='\tree -alF -I .git --gitignore'
alias treea='\tree -alF -I .git'

# Include headers and automatically follows redirects.
alias curl='\curl -iL'

# Docker aliases.
alias d='docker'
alias dps="docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

# Docker Compose aliases.
alias dc='docker compose'
alias dcps="dc ps -a --format 'table {{.Name}}\t{{.Service}}\t{{.Status}}\t{{.Ports}}'"

#####################################
#                                   #
#    git aliases and completions    #
#                                   #
#####################################

alias g='git'
__git_complete g git

alias gnuke='g nuke'

alias ga='g a'
alias gaa='g aa'
alias gapa='g apa'
__git_complete ga git_add
__git_complete gaa git_add
__git_complete gapa git_add

alias gb='g b'
alias gbr='g br'
alias gbn='g bn'
alias gbd='g bd'
alias gbdd='g bdd'
__git_complete gb git_branch
__git_complete gbr git_branch
__git_complete gbn git_checkout
__git_complete gbd git_branch
# gbdd doesn't use additional arguments.
# __git_complete gbdd git_branch

alias gc='g c'
alias gca='g ca'
alias gcm='g cm'
alias gcn='g cn'
alias gcam='g cam'
alias gcan='g can'
alias gcmn='g cmn'
alias gcamn='g camn'
alias gcw='g cw'
__git_complete gc git_commit
__git_complete gca git_commit
__git_complete gcm git_commit
__git_complete gcn git_commit
__git_complete gcam git_commit
__git_complete gcan git_commit
__git_complete gcmn git_commit
__git_complete gcamn git_commit
__git_complete gcw git_commit

alias gd='g d'
alias gdf='g df'
alias gdc='g dc'
alias gdcf='g dcf'
alias gdm='g dm'
alias gdmf='g dmf'
alias gdom='g dom'
alias gdomf='g domf'
__git_complete gd git_diff
__git_complete gdf git_diff
__git_complete gdc git_diff
__git_complete gdcf git_diff
__git_complete gdm git_diff
__git_complete gdmf git_diff
__git_complete gdom git_diff
__git_complete gdomf git_diff

alias gl='g l'
alias gll='g ll'
alias glp='g lp'
__git_complete gl git_log
__git_complete gll git_log
__git_complete glp git_log

alias gm='g m'
alias gmm='g mm'
alias gmc='g mc'
alias gma='g ma'
__git_complete gm git_merge
__git_complete gmm git_merge
__git_complete gmc git_merge
__git_complete gma git_merge

alias go='g o'
alias gom='g om'
alias gof='g of'
__git_complete go git_checkout
__git_complete gom git_checkout
__git_complete gof git_checkout

alias gpl='g pl'
__git_complete gpl git_pull

alias gps='g ps'
alias gpsf='g psf'
__git_complete gps git_push
__git_complete gpsf git_push

alias grb='g rb'
alias grbm='g rbm'
alias grbi='g rbi'
alias grbim='g rbim'
alias grbc='g rbc'
alias grba='g rba'
__git_complete grb git_rebase
__git_complete grbm git_rebase
__git_complete grbi git_rebase
__git_complete grbim git_rebase
__git_complete grbc git_rebase
__git_complete grba git_rebase

alias grs='g rs'
alias grsu='g rsu'
alias grso='g rso'
alias grsm='g rsm'
__git_complete grs git_reset
__git_complete grsu git_reset
__git_complete grso git_reset
__git_complete grsm git_reset

alias gsh='g sh'
alias gshf='g shf'
__git_complete gsh git_show
__git_complete gshf git_show

alias gst='g st'
__git_complete gst git_status

alias gt='g t'
__git_complete gt git_ls_tree

alias gw='g w'
alias gwa='g wa'
alias gwl='g wl'
alias gwp='g wp'
__git_complete gw git_worktree
__git_complete gwa git_worktree
__git_complete gwl git_worktree
__git_complete gwp git_worktree

alias gy='g y'
__git_complete gy git_cherry_pick

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
        brew update
        brew upgrade
        brew cleanup
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
fs() {
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
server() {
    local addr="${1:-0.0.0.0}"
    local port="${2:-8000}"

    sleep 2 && open "http://$addr:$port/" &
    python3 -m http.server "$port" -b "$addr"
}

# Compare original and gzipped file size.
gz() {
    local origsize=$(wc -c < "$1")
    local gzipsize=$(gzip -c "$1" | wc -c)
    local ratio=$(bc -l <<< "$gzipsize * 100 / $origsize")
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
o() {
    if [ $# -eq 0 ]; then
        open .
    else
        open "$@"
    fi
}

is_in_path() {
    builtin type -P "$1" &> /dev/null
}

cme() {
    ENV_OUTPUT=$(cm --env 2>&1)
    if [ $? -eq 0 ]; then
        eval "$ENV_OUTPUT"
    else
        echo "Error: Failed to get environment from cm" >&2
        exit 1
    fi
}

oce() {
    ENV_OUTPUT=$(oc --env 2>&1)
    if [ $? -eq 0 ]; then
        eval "$ENV_OUTPUT"
    else
        echo "Error: Failed to get environment from oc" >&2
        exit 1
    fi
}

pending_devel() {
    local devel_dir="$HOME/devel"

    if [ ! -d "$devel_dir" ]; then
        echo "Error: $devel_dir does not exist."
        return 1
    fi

    local current_dir="$(pwd)"

    find_git_repos() {
        local dir="$1"

        if [ -d "$dir/.git" ]; then
            cd "$dir"

            local main_branch=$(git main-branch)
            local repo_path="${dir#$devel_dir/}"

            if [ "$(git status --porcelain | wc -l)" -gt 0 ]; then
                echo ""
                echo -e "* \e[1m$repo_path\e[0m"
                echo ""
                git status --porcelain | head -n 10 | sed 's/^/    /'
            else
                local current_branch=$(git rev-parse --abbrev-ref HEAD)
                local upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2> /dev/null)

                if [ -n "$upstream" ]; then
                    local ahead=$(git rev-list --count @{upstream}..HEAD)
                    if [ "$ahead" -gt 0 ]; then
                        echo ""
                        echo -e "* \e[1m$repo_path\e[0m"
                        echo "    $current_branch needs to be pushed, $ahead commit(s) ahead"
                    fi
                fi

                if [ "$current_branch" != "$main_branch" ]; then
                    local main_upstream=$(git for-each-ref --format='%(upstream:short)' refs/heads/"$main_branch" 2> /dev/null)
                    if [ -n "$main_upstream" ]; then
                        local ahead=$(git rev-list --count "$main_upstream".."$main_branch")
                        if [ "$ahead" -gt 0 ]; then
                            echo ""
                            echo -e "* \e[1m$repo_path\e[0m"
                            echo -e "    $main_branch needs to be pushed, $ahead commit(s) ahead"
                        fi
                    fi
                fi
            fi

            return
        fi

        for subdir in "$dir"/*; do
            if [ -d "$subdir" ]; then
                find_git_repos "$subdir"
            fi
        done
    }

    echo -e "Checking for uncommitted changes in \e[1m~/devel\e[0m repositories..."
    find_git_repos "$devel_dir"

    cd "$current_dir"
}

j() {
    local local_bin_dir="./jpenv-bin"
    if [ ! -d "$local_bin_dir" ]; then
        echo "Local binaries directory not found" >&2
        return 1
    fi

    if [ $# -eq 0 ]; then
        local has_scripts=false
        for script in "$local_bin_dir"/*.bash; do
            if [ -f "$script" ]; then
                has_scripts=true
                echo "$(basename "$script" .bash):"
                awk '/^#\//{print substr($0,3); found=1; next} found{exit}' "$script" \
                    | sed 's/^/  /'
            fi
        done
        if [ "$has_scripts" = false ]; then
            echo "No .bash scripts found in $local_bin_dir" >&2
            return 1
        fi
        return
    fi

    script_name="$1"
    shift

    script_path="./jpenv-bin/${script_name}.bash"

    if [ ! -f "$script_path" ]; then
        echo "Error: Script '${script_name}' not found in ./jpenv-bin/" >&2
        return 1
    fi

    if grep -qxF "#: j-execute" "$script_path"; then
        local should_source=false
        local source_content=""

        while IFS= read -r line; do
            echo "$line"
            if [ "$line" = "/j-execute" ]; then
                should_source=true
            elif [ "$should_source" = true ]; then
                source_content+="$line"$'\n'
            fi
        done < <(bash "$script_path" "$@")

        if [ "$should_source" = true ] && [ -n "$source_content" ]; then
            echo ""
            echo "==== j-executing ===="
            echo ""
            eval "$source_content"
        fi

        return
    fi

    bash "$script_path" "$@"

}

je() {
    local local_bin_dir="./jpenv-bin"
    if [ ! -d "$local_bin_dir" ]; then
        echo "Local binaries directory not found" >&2
        return 1
    fi

    if [ $# -eq 0 ]; then
        local has_scripts=false
        for script in "$local_bin_dir"/*.bash; do
            if [ -f "$script" ]; then
                has_scripts=true
                echo "$(basename "$script" .bash):"
                awk '/^#\//{print substr($0,3); found=1; next} found{exit}' "$script" \
                    | sed 's/^/  /'
            fi
        done
        if [ "$has_scripts" = false ]; then
            echo "No .bash scripts found in $local_bin_dir" >&2
            return 1
        fi
        return
    fi

    script_name="$1"
    shift

    script_path="./jpenv-bin/${script_name}.bash"

    if [ ! -f "$script_path" ]; then
        echo "Script '${script_name}' not found."
        read -p "Create new script from template? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
        echo "Creating from template..."
        cat > "$script_path" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
trap 'echo "Exit status $? at line $LINENO from: $BASH_COMMAND"' ERR
cd "$(dirname "${BASH_SOURCE[0]}")/.."

#/ Documentation goes here.

# If this script needs to eval bash script at the end, add the following marker
# somewhere in the file in a line by itself:
# `#: j-execute`
# Then, output `/j-execute` in a line by itself to `stdout`, and finally outout
# the bash commands that need to be eval'd.

echo "Hello, world!"
EOF
        chmod +x "$script_path"
        echo "Created $script_path"
    fi

    $EDITOR "$script_path" "$@"
}

_j_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local jpenv_bin_dir="./jpenv-bin"

    if [ "${COMP_CWORD}" -eq 1 ] && [ -d "$jpenv_bin_dir" ]; then
        local scripts
        mapfile -t scripts < <(
            find -L "$jpenv_bin_dir" -name "*.bash" -type f -exec \
                basename {} .bash \
                \;
        )
        mapfile -t COMPREPLY < <(compgen -W "${scripts[*]}" -- "$cur")
    else
        COMPREPLY=()
        compopt -o filenames
        mapfile -t COMPREPLY < <(compgen -f -- "$cur")
    fi
}

complete -F _j_completion j
complete -F _j_completion je

loop() {
    if [ $# -eq 0 ]; then
        echo "Usage: loop <command> [args...]"
        return 1
    fi

    local run_count=0

    while true; do
        ((run_count++))
        echo "Run #$run_count: $*"
        "$@"

        local exit_code=$?
        if [ $exit_code -ne 0 ]; then
            echo "Command failed with exit code $exit_code after $run_count runs. Stopping loop."
            return $exit_code
        fi

        echo "Command completed ($run_count runs). Restarting..."
        sleep 1
    done
}

# Pass the date as the first argument, for example: 2026-01-15T14:00:00.
change_commit_date() {
    GIT_COMMITTER_DATE="$1" git commit --amend --no-edit --date="$1"
}

# Docker exec into a container with TUI selection.
dx() {
    local container_name=$(
        docker ps --format '{{.CreatedAt}}\t{{.Names}}' \
            | sort -r \
            | cut -f2 \
            | fzf --prompt="Select container to exec into: " --height=40% --reverse
    )

    if [ -z "$container_name" ]; then
        echo "No container selected."
        return 1
    fi

    echo "Executing bash in container: $container_name"
    docker exec -it "$container_name" bash
}

# Docker kill a container with TUI selection.
dk() {
    local container_name=$(
        docker ps --format '{{.CreatedAt}}\t{{.Names}}' \
            | sort -r \
            | cut -f2 \
            | fzf --prompt="Select container to kill: " --height=40% --reverse
    )

    if [ -z "$container_name" ]; then
        echo "No container selected."
        return 1
    fi

    echo "Killing container: $container_name"
    docker kill "$container_name"
}
