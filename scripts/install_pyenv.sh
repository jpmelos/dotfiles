# Select stable versions
cd ~/.pyenv
git checkout v1.2.4
cd plugins/pyenv-virtualenv
git checkout v1.1.2
cd

# Let this script use pyenv
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# Install Python versions and my default venv
pyenv install 2.7.15
pyenv install 3.4.8
pyenv install 3.5.5
pyenv install 3.6.5
pyenv virtualenv 3.6.5 myvenv
pyenv global myvenv

# Update and install default venv packages
pip install -U setuptools pip
pip install -r ~/devel/dotfiles/myvenv.txt

# Install dotfiles environment
cd ~/devel/dotfiles
pyenv virtualenv 2.7.15 dotfiles
pyenv local dotfiles
pip install -U setuptools pip
