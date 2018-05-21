#!/usr/bin/env python2.7

import os
import shlex
import shutil
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)

HOME_DIR = os.path.expanduser('~')
DEVEL_DIR = os.path.join(HOME_DIR, 'devel')

files = [
    ('gitconfig', '.gitconfig'),
    ('mybashrc', '.mybashrc'),
    ('mybashrc', '.mybash_profile'),
    ('myprofile', '.myprofile'),
    ('localserver.conf', '.localserver.conf'),
    ('tmux.conf', '.tmux.conf'),
    ('vimrc', '.vimrc'),
]


class CommandFailed(Exception):
    pass


def run(command, *args, **kwargs):
    if subprocess.call(shlex.split(command), *args, **kwargs) != 0:
        raise CommandFailed(command)


def copy_configuration_files_and_dirs():
    for item in files:
        if isinstance(item, tuple):
            source = item[0]
            destination = item[1]
        elif isinstance(item, str):
            source = item
            destination = item
        else:
            raise TypeError("Items in 'files' must be strings or tuples")

        item_path = os.path.join(HERE, source)
        home_path = os.path.join(HOME_DIR, destination)

        if os.path.exists(home_path):
            if os.path.isdir(home_path) and not os.path.islink(home_path):
                shutil.rmtree(home_path)
            else:
                os.remove(home_path)

        try:
            os.makedirs(os.path.dirname(home_path))
        except os.error:
            # Directory already exists, we can continue
            pass
        os.symlink(item_path, home_path)


def create_vim_subdirs():
    VIM_DIR = os.path.expanduser('~/.vim')
    VIM_SUBDIRS = ['backup', 'swap', 'undo']

    for directory in VIM_SUBDIRS:
        try:
            os.makedirs(os.path.join(VIM_DIR, directory))
        except os.error:
            # Directory already exists
            pass


def append_to_file(line, dest, not_found_ok=False):
    if os.path.exists(dest):
        with open(dest, mode='r') as fp:
            content = fp.read()
        if line not in content:
            with open(dest, mode='a') as fp:
                fp.write('\n' + line + '\n')
    else:
        if not not_found_ok:
            raise IOError('{} not found'.format(dest))


def source(filename, dest, not_found_ok=False):
    SOURCE_LINE = 'source ~/{filename}'.format(filename=filename)
    dest_file = os.path.join(HOME_DIR, dest)
    append_to_file(SOURCE_LINE, dest_file, not_found_ok=not_found_ok)


# Sets up the home directory and the dotfiles
copy_configuration_files_and_dirs()
source('.myprofile', '.profile', not_found_ok=True)
source('.mybashrc', '.bashrc', not_found_ok=True)
source('.mybash_profile', '.bash_profile', not_found_ok=True)

# Prepares the vim environment
create_vim_subdirs()
VUNDLE_DIR = os.path.join(HOME_DIR, '.vim/bundle/Vundle.vim')
if not os.path.exists(VUNDLE_DIR):
    run('git clone https://github.com/gmarik/Vundle.vim {}'.format(VUNDLE_DIR))
    run('vim +PluginInstall +qa')
    run('bash install_ycm.sh')

# Installs pyenv and pyenv-virtualenv, and the default myvenv
PYENV_DIR = os.path.join(HOME_DIR, '.pyenv')
PYENV_VIRTUALENV_DIR = os.path.join(PYENV_DIR, 'plugins', 'pyenv-virtualenv')
if not os.path.exists(PYENV_DIR):
    run('git clone https://github.com/pyenv/pyenv {}'.format(PYENV_DIR))
    run('git clone https://github.com/pyenv/pyenv-virtualenv {}'.format(PYENV_VIRTUALENV_DIR))
    run('rm -rf {} {}'.format(
        os.path.join(HOME_DIR, '.local', 'bin'),
        os.path.join(HOME_DIR, '.local', 'lib'),
    ))

    run('bash install_pyenv.sh')
