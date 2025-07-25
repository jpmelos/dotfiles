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

# This is called from the `$PROMPT_COMMAND`, which is defined in
# `.bash_profile`.
function run_autoenv_on_init() {
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

# The variables below don't need to be exported because we're sourcing the
# autoenv activation script.
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
alias tree='\tree -aF -I .git --gitignore'
alias treea='\tree -aF -I .git'

# Docker aliases.
alias d='docker'
alias dc='docker compose'
alias docker-nuke-all-the-things='docker rm -f $(docker ps -aq); docker system prune --all --volumes --force'

alias curl='\curl -iL'

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
alias glp='g lp'
__git_complete gl git_log
__git_complete glf git_log
__git_complete glp git_log

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
alias gdom='g dom'
__git_complete gd git_diff
__git_complete gdst git_diff
__git_complete gdca git_diff
__git_complete gdm git_diff
__git_complete gdom git_diff

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
    devel_dir="$HOME/devel"
    current_dir="$(pwd)"
    if [[ "$current_dir" != "$devel_dir"* ]]; then
        echo "Error: not inside ~/devel" >&2
        return 1
    fi

    project_relative_dir="${current_dir#"$devel_dir"/}"

    claude_help=false
    show_help=false
    profile=""

    args=()
    for arg in "$@"; do
        case "$arg" in
            --claude-help)
                claude_help=true
                ;;
            --help)
                show_help=true
                ;;
            -*)
                args+=("$arg")
                ;;
            *)
                if [[ -z "$profile" && "$arg" != "" ]]; then
                    profile="$arg"
                else
                    args+=("$arg")
                fi
                ;;
        esac
    done
    if [ ${#args[@]} -gt 0 ]; then
        echo "Error: Unrecognized arguments: ${args[*]}" >&2
        echo "Run 'cm --help' for usage information" >&2
        return 1
    fi

    if [[ "$show_help" == "true" ]]; then
        echo "Usage: cm [options] [profile]"
        echo "Options:"
        echo "  --claude-help  Show Claude help"
        echo "  --help         Show this help"
        return 0
    fi

    if [ -z "$profile" ]; then
        component_count=$(echo "$project_relative_dir" | tr '/' '\n' | wc -l)
        if [ "$component_count" -gt 1 ]; then
            profile="$(echo "$project_relative_dir" | cut -d'/' -f1)"
        else
            profile="jpmelos"
        fi
    fi

    CLAUDE_CODE_SECRET=$(
        op item get "Claude Code Configuration" \
            --vault "Private" --format json \
            | jq -r ".fields[0].value"
    )
    CLAUDE_CODE_API_KEY=$(
        toml get <(echo "$CLAUDE_CODE_SECRET") . | jq -r ".profile.$profile.api_key"
    )
    if [[ "$CLAUDE_CODE_API_KEY" == "null" ]]; then
        echo "Warning: no API key for profile '$profile', defaulting to 'jpmelos'" >&2
        profile="jpmelos"
        CLAUDE_CODE_API_KEY=$(
            toml get <(echo "$CLAUDE_CODE_SECRET") . | jq -r ".profile.$profile.api_key"
        )
    fi
    export CLAUDE_CODE_API_KEY

    export BASH_DEFAULT_TIMEOUT_MS=30000
    export BASH_MAX_TIMEOUT_MS=30000
    export MCP_TIMEOUT=10000
    export MCP_TOOL_TIMEOUT=10000

    echo "Setting up MCPs"

    claude mcp list \
        | grep '^[a-z]*:' \
        | cut -d: -f1 \
        | xargs -I {} bash -c "claude mcp remove {} > /dev/null"

    GITHUB_MCP_API_KEY=$(
        toml get <(echo "$CLAUDE_CODE_SECRET") . \
            | jq -r ".profile.$profile.github_api_token"
    )
    if [[ "$GITHUB_MCP_API_KEY" != "null" ]]; then
        claude mcp add \
            github https://api.githubcopilot.com/mcp/ \
            --scope user \
            --transport http \
            --header "Authorization: Bearer $GITHUB_MCP_API_KEY" \
            --header "X-MCP-Toolsets: repos,issues,pull_requests" \
            --header "X-MCP-Readonly: true" \
            > /dev/null
    fi

    echo "Running Claude Code with profile '$profile'"

    if [[ "$claude_help" == "true" ]]; then
        claude --help
    else
        claude
    fi
}

function pending_devel() {
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

function j() {
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
    bash "./jpenv-bin/${script_name}.bash" "$@"
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
