cd

# Let this script use pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# Install latest Python versions
while [[ -n "$1" ]]; do
    if [[ ! -d "$HOME/.pyenv/versions/$1" ]]; then
        pyenv install $1
    fi
    shift
done
