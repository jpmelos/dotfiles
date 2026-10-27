# vim: ft=bash

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
# that ran the rest of this file for nothing. Skip this inside a tmux pane
# (tmux sets `$TMUX` there), because the shell in the pane would otherwise open
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

if [[ "$PROMPT_COMMAND" != *"reset_terminal_title"* ]]; then
    export PROMPT_COMMAND="reset_terminal_title; ${PROMPT_COMMAND}"
fi
if [[ "$PROMPT_COMMAND" != *"history -n"* ]]; then
    export PROMPT_COMMAND="history -n; ${PROMPT_COMMAND}"
fi
if [[ "$PROMPT_COMMAND" != *"history -a"* ]]; then
    export PROMPT_COMMAND="history -a; ${PROMPT_COMMAND}"
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

[ -f ~/.autoenv/activate.sh ] && source ~/.autoenv/activate.sh

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

# Paste shortcut.
alias p="pbpaste"

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

if [ -f /usr/share/bash-completion/completions/git ]; then
    source /usr/share/bash-completion/completions/git
fi

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
alias gbs='g bs'
__git_complete gb git_branch
__git_complete gbc git_branch
__git_complete gbr git_branch
__git_complete gbn git_checkout
__git_complete gbd git_branch
# gbdd doesn't use additional arguments.
# __git_complete gbdd git_branch
__git_complete gbs git_branch

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

# Normalize `open` across Linux, macOS, and Windows.
# This keeps interactive `open` calls cross-platform.
if [ "$(uname -s)" != "Darwin" ]; then
    if grep -q Microsoft /proc/version; then
        # Ubuntu on Windows using the Linux subsystem
        alias open='explorer.exe'
    else
        alias open='xdg-open'
    fi
fi

# Commands that `j` falls back to when the project has no `jpenv-bin` command
# with the requested name.
JPENV_BIN_DEFAULT_DIR="$HOME/devel/dotfiles/jpenv-bin-default"

# Run a `jpenv-bin` command of the project, or a default one when the project
# has none with that name. With `--default` before the command name, skip the
# project and run the default command even when the project has one with that
# name. The command is executed directly, so it must be executable. With no
# command name, list the available commands.
j() {
    local local_bin_dir="./jpenv-bin"
    local default_bin_dir="$JPENV_BIN_DEFAULT_DIR"

    local default_only=false
    if [ "${1:-}" = "--default" ]; then
        default_only=true
        shift
    fi

    if [ $# -eq 0 ]; then
        local -a local_names=()
        if [ "$default_only" = false ] && [ -d "$local_bin_dir" ]; then
            mapfile -t local_names < <(
                find -L "$local_bin_dir" \
                    -mindepth 1 -maxdepth 1 \
                    -type f -exec \
                    basename {} \
                    \;
            )
        fi

        local listing
        listing="$(
            if [ "$default_only" = false ]; then
                j_list_commands "$local_bin_dir" ""
            fi
            # A local command with the same name shadows the default one.
            j_list_commands "$default_bin_dir" " (default)" "${local_names[@]}"
        )"
        if [ -z "$listing" ]; then
            if [ "$default_only" = true ]; then
                echo "No commands found in $default_bin_dir" >&2
            else
                echo "No commands found in $local_bin_dir" \
                    "or $default_bin_dir" >&2
            fi
            return 1
        fi
        echo "$listing"
        return
    fi

    local command_name="$1"
    shift

    local command_path="$local_bin_dir/$command_name"
    if [ "$default_only" = true ] || [ ! -f "$command_path" ]; then
        command_path="$default_bin_dir/$command_name"
    fi

    if [ ! -f "$command_path" ]; then
        if [ "$default_only" = true ]; then
            echo "Error: Command '${command_name}'" \
                "not found in $default_bin_dir" >&2
        else
            echo "Error: Command '${command_name}'" \
                "not found in $local_bin_dir" \
                "or $default_bin_dir" >&2
        fi
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

# Run a default `jpenv-bin` command, even when the project has one with the
# same name.
alias jd='j --default'

je() {
    local local_bin_dir="./jpenv-bin"
    if [ ! -d "$local_bin_dir" ]; then
        echo "Local binaries directory not found" >&2
        return 1
    fi

    if [ $# -eq 0 ]; then
        local listing
        listing="$(j_list_commands "$local_bin_dir" "")"
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

# List branches with worktrees, without the main repository.
# Used to complete `j worktree rm`.
_j_worktree_branches() {
    local common_dir main_dir
    common_dir="$(git rev-parse --path-format=absolute --git-common-dir \
        2> /dev/null)" || return 0
    main_dir="$(dirname "$common_dir")"
    git worktree list --porcelain 2> /dev/null | awk -v main="$main_dir" '
        /^worktree / {
            if (path != "" && branch != "" && path != main) {
                print branch
            }
            path = substr($0, 10)
            branch = ""
            next
        }
        /^branch refs\/heads\// {
            branch = substr($0, length("branch refs/heads/") + 1)
        }
        END {
            if (path != "" && branch != "" && path != main) {
                print branch
            }
        }
    '
}

_j_completion() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local jpenv_bin_dir="./jpenv-bin"

    local -a command_dirs=("$jpenv_bin_dir")
    # Only `j` falls back to the default commands.
    if [ "$1" = "j" ]; then
        command_dirs+=("$JPENV_BIN_DEFAULT_DIR")
    fi

    # The position of the command name. With `j --default`, the flag takes
    # the first position and only the default commands apply. `jd` stands for
    # `j --default`, so only the default commands apply there too.
    local command_position=1
    local -a extra_words=()
    if [ "$1" = "jd" ]; then
        command_dirs=("$JPENV_BIN_DEFAULT_DIR")
    elif [ "$1" = "j" ]; then
        if [ "${COMP_WORDS[1]:-}" = "--default" ]; then
            command_position=2
            command_dirs=("$JPENV_BIN_DEFAULT_DIR")
        else
            extra_words=("--default")
        fi
    fi

    # Complete `worktree` subcommands and `worktree rm` branches.
    # `je` edits local commands, so it keeps the filename fallback below.
    if [ "$1" = "j" ] || [ "$1" = "jd" ]; then
        if [ "${COMP_CWORD}" -gt "$command_position" ]; then
            local worktree_command="${COMP_WORDS[$command_position]:-}"
            if [ "$worktree_command" = "worktree" ]; then
                local subcommand_position=$((command_position + 1))
                if [ "${COMP_CWORD}" \
                    -eq "$subcommand_position" ]; then
                    mapfile -t COMPREPLY < <(compgen -W "new rm ls" -- "$cur")
                    return 0
                fi
                local subcommand="${COMP_WORDS[$subcommand_position]:-}"
                if [ "$subcommand" = "rm" ]; then
                    if [ "${COMP_CWORD}" \
                        -eq $((subcommand_position + 1)) ]; then
                        local -a branches=()
                        mapfile -t branches < <(_j_worktree_branches)
                        if [ "${#branches[@]}" -gt 0 ]; then
                            mapfile -t COMPREPLY < <(compgen -W \
                                "${branches[*]}" -- "$cur")
                        else
                            COMPREPLY=()
                        fi
                        return 0
                    fi
                    COMPREPLY=()
                    return 0
                fi
                if [ "$subcommand" = "ls" ]; then
                    COMPREPLY=()
                    return 0
                fi
            fi
        fi
    fi

    local -a commands=()
    if [ "${COMP_CWORD}" -eq "$command_position" ]; then
        mapfile -t commands < <(
            for command_dir in "${command_dirs[@]}"; do
                [ -d "$command_dir" ] || continue
                find -L "$command_dir" -mindepth 1 -maxdepth 1 -type f -exec \
                    basename {} \
                    \;
            done | sort -u
        )
        commands+=("${extra_words[@]}")
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
complete -F _j_completion jd
complete -F _j_completion je

#########################################
#                                       #
#    Project navigation with ~/devel    #
#                                       #
#########################################

# Navigate to a project in ~/devel with TUI selection.
x() {
    local project
    project=$(
        {
            echo "Projects Root"
            list_project_dirs
        } | fzf --prompt="Select project: " --height=40% --reverse --query="$*"
    )

    if [ "$project" = "Projects Root" ] || [ -z "$project" ]; then
        cd "$HOME/devel"
    else
        cd "$HOME/devel/$project"
    fi
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
alias dcps="docker compose ps \
    --format 'table {{.Name}}\t{{.Service}}\t{{.Status}}\t{{.Ports}}'"
alias dcpsa="docker compose ps -a \
    --format 'table {{.Name}}\t{{.Service}}\t{{.Status}}\t{{.Ports}}'"
alias dcls="docker compose ls"
