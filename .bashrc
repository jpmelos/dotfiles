# vim: ft=sh

# Set up the GPG Agent.
export GPG_TTY=$(tty)

##############
#            #
#    tmux    #
#            #
##############

# Replace an interactive shell with a tmux client when it starts. Attach to the
# running server if there is one, otherwise start a new server. The `exec`
# makes the terminal close when the client exits, instead of leaving a shell
# that ran the rest of this file for nothing. Skip this inside a tmux pane (tmux
# sets `$TMUX` there), because the shell in the pane would otherwise open
# another client, forever.
if [[ $- == *i* ]] && [ -z "$TMUX" ] && command -v tmux &> /dev/null; then
    if tmux has-session &> /dev/null; then
        exec tmux attach-session
    else
        exec tmux new-session
    fi
fi

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

BASH_TERMINAL_TITLE="bash"
reset_terminal_title() {
    echo -ne "\033]0;$BASH_TERMINAL_TITLE\007"
}

# Print the name of the project that holds the current directory, as
# `list_project_dirs` reports it. In a linked git worktree, print the name of
# the main repository, a colon, and the checked-out branch instead. Print
# nothing when the current directory is inside no project.
current_project_name() {
    local devel_dir
    devel_dir="$(realpath "$HOME/devel" 2> /dev/null)" || return 0
    local current_dir
    current_dir="$(pwd -P 2> /dev/null)" || return 0
    [[ "$current_dir" == "$devel_dir"/* ]] || return 0

    # Walk down from `~/devel`. The first directory with a `.git` entry and no
    # `.list_project_dirs_ignore` file is the project. Both paths above are
    # resolved, so no component on the way is a link.
    local -a components
    IFS='/' read -r -a components <<< "${current_dir#"$devel_dir"/}"
    local project_dir=""
    local candidate="$devel_dir"
    local component
    for component in "${components[@]}"; do
        candidate="$candidate/$component"
        if [ -e "$candidate/.git" ] && [ ! -e "$candidate/.list_project_dirs_ignore" ]; then
            project_dir="$candidate"
            break
        fi
    done
    [ -n "$project_dir" ] || return 0

    local name="${project_dir#"$devel_dir"/}"

    # In a linked worktree, `.git` is a file, and the git directory differs
    # from the common directory of the main repository. A submodule has a
    # `.git` file too, but there the two directories are the same.
    if [ -f "$project_dir/.git" ]; then
        local -a git_dirs
        mapfile -t git_dirs < <(
            git -C "$project_dir" rev-parse --path-format=absolute \
                --git-dir --git-common-dir 2> /dev/null
        )
        if [ "${#git_dirs[@]}" -eq 2 ] && [ "${git_dirs[0]}" != "${git_dirs[1]}" ]; then
            local main_repo_dir
            main_repo_dir="$(realpath "${git_dirs[1]}")"
            main_repo_dir="${main_repo_dir%/.git}"
            local main_repo_name
            if [[ "$main_repo_dir" == "$devel_dir"/* ]]; then
                main_repo_name="${main_repo_dir#"$devel_dir"/}"
            else
                main_repo_name="$(basename "$main_repo_dir")"
            fi

            local branch
            branch="$(git -C "$project_dir" branch --show-current 2> /dev/null)"
            if [ -z "$branch" ]; then
                # Detached HEAD. Show the commit instead.
                branch="$(git -C "$project_dir" rev-parse --short HEAD 2> /dev/null)"
            fi

            name="$main_repo_name: $branch"
        fi
    fi

    echo "$name"
}

# The project name that this shell last wrote to its tmux window. Empty when
# the shell was never in a project, or when it left the last one.
TMUX_WINDOW_PROJECT=""

# Name the tmux window of this shell after the project of the current
# directory. Act only when the project changes from the last prompt, so that a
# shell that stays in place, or that was never in a project, does not touch a
# name that another pane or the user set. On the way into a project, rename
# the window, which also turns `automatic-rename` off for it. On the way out,
# unset `automatic-rename` for the window, so that the global default applies
# again and tmux names the window by its own scheme.
set_tmux_window_project() {
    { [ -n "$TMUX" ] && [ -n "$TMUX_PANE" ]; } || return 0

    local project_name
    project_name="$(current_project_name)"
    [ "$project_name" != "$TMUX_WINDOW_PROJECT" ] || return 0
    TMUX_WINDOW_PROJECT="$project_name"

    if [ -n "$project_name" ]; then
        tmux rename-window -t "$TMUX_PANE" "$project_name" 2> /dev/null
    else
        tmux set-option -w -u -t "$TMUX_PANE" automatic-rename 2> /dev/null
    fi
}

if [[ "$PROMPT_COMMAND" != *"reset_terminal_title"* ]]; then
    export PROMPT_COMMAND="history -a; history -n; reset_terminal_title; set_tmux_window_project; ${PROMPT_COMMAND}"
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

# Enable autoenv leave too.
export AUTOENV_ENABLE_LEAVE=1
# Rename autoenv files to less generic names.
export AUTOENV_ENV_FILENAME=.autoenv.enter
export AUTOENV_ENV_LEAVE_FILENAME=.autoenv.leave

source ~/devel/autoenv/activate.sh

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

# Current datetime in a machine-readable format.
alias dt="date '+%Y-%m-%dT%H:%M:%S'"

# Always ignore the .git directory.
alias tree='\tree -alF -I .git --gitignore'
alias treea='\tree -alF -I .git'

# Include headers and automatically follows redirects.
alias curl='\curl -iL'

alias py='python3'
alias py3='python3'
alias python='python3'

#####################################
#                                   #
#    git aliases and completions    #
#                                   #
#####################################

alias g='git'
__git_complete g git

alias gnuke='g nuke'

alias ga='g a'
alias gan='g an'
alias gaa='g aa'
alias gana='g ana'
alias gapa='g apa'
__git_complete ga git_add
__git_complete gan git_add
__git_complete gaa git_add
__git_complete gana git_add
__git_complete gapa git_add

alias gb='g b'
alias gbc='g bc'
alias gbr='g br'
alias gbn='g bn'
alias gbd='g bd'
alias gbdd='g bdd'
__git_complete gb git_branch
__git_complete gbc git_branch
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

alias gf='g f'
__git_complete gf git_fetch

alias gl='g l'
alias gll='g ll'
alias glp='g lp'
__git_complete gl git_log
__git_complete gll git_log
__git_complete glp git_log

alias gm='g m'
alias gmm='g mm'
alias gmom='g mom'
alias gmc='g mc'
alias gma='g ma'
__git_complete gm git_merge
__git_complete gmm git_merge
__git_complete gmom git_merge
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
alias grbom='g rbom'
alias grbi='g rbi'
alias grbim='g rbim'
alias grbiom='g rbiom'
alias grbc='g rbc'
alias grba='g rba'
__git_complete grb git_rebase
__git_complete grbm git_rebase
__git_complete grbom git_rebase
__git_complete grbi git_rebase
__git_complete grbim git_rebase
__git_complete grbiom git_rebase
__git_complete grbc git_rebase
__git_complete grba git_rebase

alias grs='g rs'
alias grso='g rso'
alias grsm='g rsm'
alias grsu='g rsu'
alias grsum='g rsum'
__git_complete grs git_reset
__git_complete grso git_reset
__git_complete grsm git_reset
__git_complete grsu git_reset
__git_complete grsum git_reset

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
if [ "$(uname -s)" = "Darwin" ]; then
    default_if() {
        route -n get default | grep 'interface:' | awk '{print $2}'
    }
else
    default_if() {
        echo "Implement for Linux..."
    }
fi

# Find the IP of the interface to the default gateway.
if [ "$(uname -s)" = "Darwin" ]; then
    default_if_ip() {
        ifconfig "$(default_if)" | grep 'inet ' | awk '{print $2}'
    }
else
    default_if_ip() {
        echo "Implement for Linux..."
    }
fi

# Updates the system.
if [ "$(uname -s)" = "Darwin" ]; then
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

# Start an HTTP server from a directory, optionally specifying the port.
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
if [ "$(uname -s)" != "Darwin" ]; then
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

pending_devel() {
    local devel_dir="$HOME/devel"

    if [ ! -d "$devel_dir" ]; then
        echo "Error: $devel_dir does not exist."
        return 1
    fi

    local current_dir="$(pwd)"

    local -a projects
    mapfile -t projects < <(list_project_dirs)
    local total="${#projects[@]}"

    if [ "$total" -eq 0 ]; then
        echo -e "No projects found in \e[1m~/devel\e[0m."
        return 0
    fi

    echo -e "Checking for uncommitted changes in \e[1m~/devel\e[0m repositories ($total projects)..."

    local bar_width=40
    local index=0
    local -a findings=()
    local repo_path
    for repo_path in "${projects[@]}"; do
        index=$((index + 1))

        local filled=$((index * bar_width / total))
        local bar=""
        local i
        for ((i = 0; i < filled; i++)); do bar+="="; done
        for ((i = filled; i < bar_width; i++)); do bar+=" "; done
        printf "\r[%s] %d/%d" "$bar" "$index" "$total"

        cd "$devel_dir/$repo_path"

        local main_branch
        main_branch=$(git main-branch)

        if [ "$(git status --porcelain | wc -l)" -gt 0 ]; then
            local status_output
            status_output=$(git status --porcelain | head -n 10 | sed 's/^/    /')
            findings+=("$(printf "* \033[1m%s\033[0m\n\n%s" "$repo_path" "$status_output")")
        else
            local should_pull=true

            local current_branch
            current_branch=$(git rev-parse --abbrev-ref HEAD)
            local upstream
            upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2> /dev/null || true)

            if [ -n "$upstream" ]; then
                local ahead
                ahead=$(git rev-list --count @{upstream}..HEAD)
                if [ "$ahead" -gt 0 ]; then
                    should_pull=false
                    findings+=("$(printf "* \033[1m%s\033[0m\n    %s needs to be pushed, %d commit(s) ahead" \
                        "$repo_path" "$current_branch" "$ahead")")
                fi
            fi

            if [ "$current_branch" != "$main_branch" ]; then
                should_pull=false

                local main_upstream
                main_upstream=$(git for-each-ref --format='%(upstream:short)' refs/heads/"$main_branch" 2> /dev/null)
                if [ -n "$main_upstream" ]; then
                    local main_ahead
                    main_ahead=$(git rev-list --count "$main_upstream".."$main_branch")
                    if [ "$main_ahead" -gt 0 ]; then
                        findings+=("$(printf "* \033[1m%s\033[0m\n    %s needs to be pushed, %d commit(s) ahead" \
                            "$repo_path" "$main_branch" "$main_ahead")")
                    fi
                fi
            fi

            if [ "$should_pull" = true ]; then
                local pull_output
                if ! pull_output=$(git pull --quiet 2>&1); then
                    pull_output=$(printf "%s" "$pull_output" | sed 's/^/    /')
                    findings+=("$(printf "* \033[1m%s\033[0m\n    git pull failed:\n%s" \
                        "$repo_path" "$pull_output")")
                fi
            fi
        fi
    done

    echo ""
    local finding
    for finding in "${findings[@]}"; do
        echo ""
        printf "%s\n" "$finding"
    done

    cd "$current_dir"
}

# Commands that `j` falls back to when the project has no `jpenv-bin` command
# with the requested name.
JPENV_BIN_DEFAULT_DIR="$HOME/devel/dotfiles/jpenv-bin-default"

# Print the name of each regular file in the directory, followed by the
# documentation block that its `#/` lines hold. Skip files whose names are in
# the remaining arguments.
_j_list_commands() {
    local bin_dir="$1"
    local suffix="$2"
    shift 2
    local -a skipped_names=("$@")

    local command_path
    for command_path in "$bin_dir"/*; do
        [ -f "$command_path" ] || continue
        local command_name
        command_name="$(basename "$command_path")"
        local skipped_name
        for skipped_name in "${skipped_names[@]}"; do
            [ "$command_name" = "$skipped_name" ] && continue 2
        done
        echo "${command_name}:${suffix}"
        awk '/^#\//{print substr($0,3); found=1; next} found{exit}' "$command_path" \
            | sed 's/^/  /'
    done
}

# Run a `jpenv-bin` command of the project, or a default one when the project
# has none with that name. The command is executed directly, so it must be
# executable. With no arguments, list the available commands.
j() {
    local local_bin_dir="./jpenv-bin"
    local default_bin_dir="$JPENV_BIN_DEFAULT_DIR"

    if [ $# -eq 0 ]; then
        local -a local_names=()
        if [ -d "$local_bin_dir" ]; then
            mapfile -t local_names < <(
                find -L "$local_bin_dir" -mindepth 1 -maxdepth 1 -type f -exec \
                    basename {} \
                    \;
            )
        fi

        local listing
        listing="$(
            _j_list_commands "$local_bin_dir" ""
            # A local command with the same name shadows the default one.
            _j_list_commands "$default_bin_dir" " (default)" "${local_names[@]}"
        )"
        if [ -z "$listing" ]; then
            echo "No commands found in $local_bin_dir or $default_bin_dir" >&2
            return 1
        fi
        echo "$listing"
        return
    fi

    local command_name="$1"
    shift

    local command_path="$local_bin_dir/$command_name"
    if [ ! -f "$command_path" ]; then
        command_path="$default_bin_dir/$command_name"
    fi

    if [ ! -f "$command_path" ]; then
        echo "Error: Command '${command_name}' not found in $local_bin_dir or $default_bin_dir" >&2
        return 1
    fi

    if grep -qxF "#: j-execute" "$command_path"; then
        local should_source=false
        local source_content=""

        while IFS= read -r line; do
            echo "$line"
            if [ "$line" = "/j-execute" ]; then
                should_source=true
            elif [ "$should_source" = true ]; then
                source_content+="$line"$'\n'
            fi
        done < <("$command_path" "$@")

        if [ "$should_source" = true ] && [ -n "$source_content" ]; then
            echo ""
            echo "==== j-executing ===="
            echo ""
            eval "$source_content"
        fi

        return
    fi

    "$command_path" "$@"
}

je() {
    local local_bin_dir="./jpenv-bin"
    if [ ! -d "$local_bin_dir" ]; then
        echo "Local binaries directory not found" >&2
        return 1
    fi

    if [ $# -eq 0 ]; then
        local listing
        listing="$(_j_list_commands "$local_bin_dir" "")"
        if [ -z "$listing" ]; then
            echo "No commands found in $local_bin_dir" >&2
            return 1
        fi
        echo "$listing"
        return
    fi

    local command_name="$1"
    shift

    local command_path="$local_bin_dir/$command_name"

    if [ ! -f "$command_path" ]; then
        echo "Command '${command_name}' not found."
        read -p "Create new command from template? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
        echo "Creating from template..."
        cat > "$command_path" << 'EOF'
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
        chmod +x "$command_path"
        echo "Created $command_path"
    fi

    $EDITOR "$command_path" "$@"
}

_j_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local jpenv_bin_dir="./jpenv-bin"

    local -a command_dirs=("$jpenv_bin_dir")
    # Only `j` falls back to the default commands.
    if [ "$1" = "j" ]; then
        command_dirs+=("$JPENV_BIN_DEFAULT_DIR")
    fi

    local -a commands=()
    if [ "${COMP_CWORD}" -eq 1 ]; then
        mapfile -t commands < <(
            for command_dir in "${command_dirs[@]}"; do
                [ -d "$command_dir" ] || continue
                find -L "$command_dir" -mindepth 1 -maxdepth 1 -type f -exec \
                    basename {} \
                    \;
            done | sort -u
        )
    fi

    if [ "${#commands[@]}" -gt 0 ]; then
        mapfile -t COMPREPLY < <(compgen -W "${commands[*]}" -- "$cur")
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
# Defaults to current date if not provided.
change_commit_date() {
    # Check if there are any staged or unstaged changes (excluding untracked files).
    if ! git diff-index --quiet HEAD --; then
        echo "Error: Working directory has staged or unstaged changes. Please commit or stash them first." >&2
        return 1
    fi

    local date="${1:-$(date '+%Y-%m-%dT%H:%M:%S')}"
    GIT_COMMITTER_DATE="$date" git commit --amend --no-verify --no-edit --date="$date"
}

format_duration() {
    local total_seconds="$1"

    local days=$((total_seconds / 86400))
    local hours=$(((total_seconds % 86400) / 3600))
    local minutes=$(((total_seconds % 3600) / 60))
    local secs=$((total_seconds % 60))

    local duration=""
    if [ "$days" -gt 0 ]; then
        duration="${days}d${hours}h${minutes}m${secs}s"
    elif [ "$hours" -gt 0 ]; then
        duration="${hours}h${minutes}m${secs}s"
    elif [ "$minutes" -gt 0 ]; then
        duration="${minutes}m${secs}s"
    else
        duration="${secs}s"
    fi

    echo "$duration"
}
export -f format_duration

# If only a time is given (HH:MM or HH:MM:SS), today is assumed. Seconds are optional.
run_until() {
    local deadline="$1"
    shift

    # If only a time is given, prepend today's date.
    if [[ "$deadline" =~ ^[0-9]{2}:[0-9]{2}(:[0-9]{2})?$ ]]; then
        deadline="$(date '+%Y-%m-%d') $deadline"
    fi

    # If seconds are missing, append ":00".
    if [[ "$deadline" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}$ ]]; then
        deadline="$deadline:00"
    fi

    local deadline_epoch
    deadline_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$deadline" +%s) || {
        echo "Invalid date format. Use: YYYY-MM-DD HH:MM[:SS] or HH:MM[:SS]"
        return 1
    }

    local now_epoch
    now_epoch=$(date +%s)

    local seconds_left=$((deadline_epoch - now_epoch))

    if [ "$seconds_left" -le 0 ]; then
        echo "Deadline already passed"
        return 1
    fi

    echo "Running for $(format_duration "$seconds_left")..."
    timeout "$seconds_left" "$@"
}

# Pretty-print the JSON in the clipboard. Prints the formatted JSON to stdout
# and replaces the clipboard contents with it. If the clipboard does not hold
# valid JSON, `jq` reports the error and the clipboard is left unchanged.
pretty_json() {
    local pretty
    pretty=$(pbpaste | jq '.') || return
    echo "$pretty"
    echo "$pretty" | pbcopy
}

#########################################
#                                       #
#    Project navigation with ~/devel    #
#                                       #
#########################################

# Navigate to a project in ~/devel with TUI selection.
x() {
    local project
    project=$(
        list_project_dirs \
            | fzf --prompt="Select project: " --height=40% --reverse --query="$*"
    )

    if [ -z "$project" ]; then
        echo "No project selected."
        return 1
    fi

    cd "$HOME/devel/$project"
}

################
#              #
#    Docker    #
#              #
################

# Docker aliases.
alias d='docker'
alias dps="docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
alias dpsa="docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
alias drm="docker rm -f"
alias drma='docker rm -f $(docker ps -aq)'
alias dpause='docker pause $(docker ps -aq)'
alias dunpause='docker unpause $(docker ps -aq)'

# Docker Compose aliases.
alias dc='docker compose'
alias dcps="docker compose ps --format 'table {{.Name}}\t{{.Service}}\t{{.Status}}\t{{.Ports}}'"
alias dcpsa="docker compose ps -a --format 'table {{.Name}}\t{{.Service}}\t{{.Status}}\t{{.Ports}}'"
alias dcls="docker compose ls"
dcrm() { # Drop an active Docker Compose environment.
    docker compose -p "$1" down
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

######################################
#                                    #
#    1Password local configuration   #
#                                    #
######################################

# Manage the "Local Configuration" 1Password note as `~/config.json`.
jc() {
    local subcommand="${1:-}"

    if [ -z "$subcommand" ]; then
        echo "Usage: jc <get|save>"
        return 1
    fi

    case "$subcommand" in
        get)
            local op_json
            if ! op_json=$(op item get "Local Configuration" --fields notesPlain --format json 2>&1); then
                echo "Error: Failed to get 'Local Configuration' from 1Password:" >&2
                echo "$op_json" >&2
                return 1
            fi
            op_content=$(jq -r '.value' <<< "$op_json")

            if [ -f ~/config.json ]; then
                local diff_output
                diff_output=$(diff ~/config.json <(printf '%s\n' "$op_content"))
                if [ -z "$diff_output" ]; then
                    chmod 600 ~/config.json
                    echo "No differences found. Local file is already up to date."
                    return 0
                fi

                echo "Diff (local → 1Password):"
                echo "$diff_output"
                echo ""
                read -r -n 1 -p "Overwrite ~/config.json with 1Password content? [y/N] "
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo "Cancelled."
                    return 0
                fi
            fi

            printf '%s\n' "$op_content" > ~/config.json
            chmod 600 ~/config.json
            echo "Saved to ~/config.json."
            ;;
        save)
            local op_json
            if ! op_json=$(op item get "Local Configuration" --fields notesPlain --format json 2>&1); then
                echo "Error: Failed to get 'Local Configuration' from 1Password:" >&2
                echo "$op_json" >&2
                return 1
            fi
            op_content=$(jq -r '.value' <<< "$op_json")

            if [ ! -f ~/config.json ]; then
                echo "Error: ~/config.json does not exist." >&2
                return 1
            fi

            local diff_output
            diff_output=$(diff <(printf '%s\n' "$op_content") ~/config.json)
            if [ -z "$diff_output" ]; then
                echo "No differences found. 1Password is already up to date."
                return 0
            fi

            echo "Diff (1Password → local):"
            echo "$diff_output"
            echo ""
            read -r -n 1 -p "Update 1Password with local content? [y/N] "
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "Cancelled."
                return 0
            fi

            local local_content
            local_content=$(cat ~/config.json)
            if ! op item edit "Local Configuration" "notesPlain=$local_content"; then
                echo "Error: Failed to update 'Local Configuration' in 1Password." >&2
                return 1
            fi
            echo "Updated 1Password successfully."
            ;;
        *)
            echo "Error: Unknown subcommand '$subcommand'. Use 'get' or 'save'." >&2
            return 1
            ;;
    esac
}
