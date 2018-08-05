# Select stable versions
cd ~/.pyenv
git checkout $1
shift
cd plugins/pyenv-virtualenv
git checkout $1
shift
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
    LATEST_PYTHON_VERSION=$1
    shift
done

# Update and install default venv packages
pyenv virtualenv $LATEST_PYTHON_VERSION myvenv
pyenv global myvenv
pip install -U setuptools pip
pip install -r ~/devel/dotfiles/references/myvenv.txt
