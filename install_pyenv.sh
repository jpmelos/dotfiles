export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

pyenv install 3.6.5
pyenv virtualenv 3.6.5 myvenv
pyenv global myvenv
pyenv versions

pip install -U setuptools pip
pip install -r ~/devel/dotfiles/myvenv.txt
