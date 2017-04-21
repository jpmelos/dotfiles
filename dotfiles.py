#!/usr/bin/env python3.6

import os
import shlex
import shutil
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
os.chdir(HERE)

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
    ('sublime-text', '.config/sublime-text-3/Packages/User'),
]


class CommandFailed(Exception):
    pass


def run(command, *args, **kwargs):
    if subprocess.run(shlex.split(command), *args, **kwargs).returncode != 0:
        raise CommandFailed(command)


def copy_configuration_files_and_dirs():
    for item in files:
        if isinstance(item, tuple):
            ITEM_PATH = os.path.join(HERE, item[0])
            HOME_PATH = os.path.join(HOME_DIR, item[1])
        else:
            ITEM_PATH = os.path.join(HERE, item)
            HOME_PATH = os.path.join(HOME_DIR, item)

        if os.path.exists(HOME_PATH):
            if os.path.isdir(HOME_PATH) and not os.path.islink(HOME_PATH):
                shutil.rmtree(HOME_PATH)
            else:
                os.remove(HOME_PATH)

        os.makedirs(os.path.dirname(HOME_PATH), exist_ok=True)
        os.symlink(ITEM_PATH, HOME_PATH)


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
    run('git clone https://github.com/gmarik/Vundle.vim.git {}'.format(VUNDLE_DIR))
