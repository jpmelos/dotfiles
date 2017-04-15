#!/usr/bin/env python3.5

import os
import shlex
import shutil
import subprocess

os.chdir(os.path.dirname(os.path.abspath(__file__)))

HOME_DIR = os.path.expanduser('~')
DEVEL_DIR = os.path.join(HOME_DIR, 'devel')

files = [
    '.gitconfig',
    'localserver.conf',
    '.mybashrc',
    '.myprofile',
    ('.myprofile', '.mybash_profile'),
    '.tmux.conf',
    '.vimrc',

    # Sublime Text files
    ('sublime-text/Preferences.sublime-settings',
     '.config/sublime-text-3/Packages/User/Preferences.sublime-settings'),
    ('sublime-text/HTML.sublime-settings',
     '.config/sublime-text-3/Packages/User/HTML.sublime-settings'),
    ('sublime-text/Sass.sublime-settings',
     '.config/sublime-text-3/Packages/User/Sass.sublime-settings'),
    ('sublime-text/JavaScript.sublime-settings',
     '.config/sublime-text-3/Packages/User/JavaScript.sublime-settings'),
    ('sublime-text/JSON.sublime-settings',
     '.config/sublime-text-3/Packages/User/JSON.sublime-settings'),
    ('sublime-text/Python.sublime-settings',
     '.config/sublime-text-3/Packages/User/Python.sublime-settings'),
    ('sublime-text/PHP.sublime-settings',
     '.config/sublime-text-3/Packages/User/PHP.sublime-settings'),
    ('sublime-text/Shell-Unix-Generic.sublime-settings',
     '.config/sublime-text-3/Packages/User/Shell-Unix-Generic.sublime-settings'),
    ('sublime-text/project_manager.sublime-settings',
     '.config/sublime-text-3/Packages/User/project_manager.sublime-settings'),
]


class CommandFailed(Exception):
    pass


def run(command, *args, **kwargs):
    if subprocess.run(shlex.split(command), *args, **kwargs).returncode != 0:
        raise CommandFailed(command)


def copy_configuration_files_and_dirs():
    for item in files:
        if isinstance(item, tuple):
            ITEM_NAME = item[0]
            HOME_COPY = os.path.join(HOME_DIR, item[1])
        else:
            ITEM_NAME = item
            HOME_COPY = os.path.join(HOME_DIR, item)

        if os.path.isdir(ITEM_NAME):
            if os.path.exists(HOME_COPY):
                shutil.rmtree(HOME_COPY)
            shutil.copytree(ITEM_NAME, HOME_COPY)
        else:
            os.makedirs(os.path.dirname(HOME_COPY), exist_ok=True)
            shutil.copy(ITEM_NAME, HOME_COPY)


def create_vim_subdirs():
    VIM_DIR = os.path.expanduser('~/.vim')
    VIM_SUBDIRS = ['backup', 'swap', 'undo']

    for directory in VIM_SUBDIRS:
        os.makedirs(os.path.join(VIM_DIR, directory), exist_ok=True)


def source(filename, dest):
    SOURCE_LINE = 'source ~/{filename}'.format(filename=filename)
    dest_file = os.path.join(HOME_DIR, dest)
    if os.path.exists(dest_file):
        with open(dest_file, mode='r') as fp:
            content = fp.read()
        if SOURCE_LINE not in content:
            with open(dest_file, mode='a') as fp:
                fp.write('\n' + SOURCE_LINE + '\n')


copy_configuration_files_and_dirs()
source('.mybashrc', '.bashrc')
source('.myprofile', '.profile')
source('.mybash_profile', '.bash_profile')

create_vim_subdirs()

VUNDLE_DIR = os.path.join(HOME_DIR, '.vim/bundle/Vundle.vim')
if not os.path.exists(VUNDLE_DIR):
    run('git clone https://github.com/gmarik/Vundle.vim.git '
        '{}'.format(VUNDLE_DIR))

os.chdir(DEVEL_DIR)
GNOME_TERMINAL_COLORS_DIR = os.path.join(DEVEL_DIR, 'gnome-terminal-colors')
if not os.path.exists(GNOME_TERMINAL_COLORS_DIR):
    run('git clone git@github.com:jpmelos/gnome-terminal-colors')
    os.chdir(GNOME_TERMINAL_COLORS_DIR)
    run('bash install.sh')
