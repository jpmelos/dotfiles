#!/usr/bin/env python3

from subprocess import check_output as proc_run, DEVNULL, PIPE
from shlex import split
from shutil import copy, copytree, rmtree
from os import getenv, chdir
from os.path import dirname, abspath, isdir, join, exists


HOME_DIR = getenv('HOME')
BASE_DIR = dirname(abspath(__file__))


files = [
    ('.fonts', '.fonts'),
    ('.gitconfig', '.gitconfig'),
    ('localserver.conf', 'localserver.conf'),
    ('.mybashrc', '.mybashrc'),
    ('.mybash_profile', '.mybash_profile'),
    ('Preferences.sublime-settings', '.config/sublime-text-3/Packages/User/Preferences.sublime-settings'),
    ('HTML.sublime-settings', '.config/sublime-text-3/Packages/User/HTML.sublime-settings'),
    ('Sass.sublime-settings', '.config/sublime-text-3/Packages/User/Sass.sublime-settings'),
    ('JavaScript.sublime-settings', '.config/sublime-text-3/Packages/User/JavaScript.sublime-settings'),
    ('JSON.sublime-settings', '.config/sublime-text-3/Packages/User/JSON.sublime-settings'),
    ('Python.sublime-settings', '.config/sublime-text-3/Packages/User/Python.sublime-settings'),
    ('.tmux.conf', '.tmux.conf'),
    ('.vimrc', '.vimrc'),
]


def source(filename):
    SOURCE = 'source ~/.my{filename}'.format(filename=filename)
    with open(join(HOME_DIR, '.{filename}'.format(filename=filename)), mode='r') as fp:
        content = fp.read()
    if SOURCE not in content:
        with open(join(HOME_DIR, '.{filename}'.format(filename=filename)), mode='a') as fp:
            fp.write('\n' + SOURCE + '\n')


for item in files:
    HOME_COPY = join(HOME_DIR, item[1])
    if isdir(item[0]):
        if exists(HOME_COPY):
            rmtree(HOME_COPY)
        copytree(item[0], HOME_COPY)
    else:
        copy(item[0], HOME_COPY)

source('bashrc')
source('bash_profile')
