#!/usr/bin/env python3

from shutil import copy, copytree, rmtree
from os import getenv
from os.path import dirname, abspath, isdir, join, exists


HOME_DIR = getenv('HOME')
BASE_DIR = dirname(abspath(__file__))


files = [
    '.fonts',
    '.gitconfig',
    'localserver.conf',
    '.mybashrc',
    '.mybash_profile',
    '.tmux.conf',
    '.vimrc',

    # Sublime Text files
    ('Preferences.sublime-settings',
     '.config/sublime-text-3/Packages/User/Preferences.sublime-settings'),
    ('HTML.sublime-settings',
     '.config/sublime-text-3/Packages/User/HTML.sublime-settings'),
    ('Sass.sublime-settings',
     '.config/sublime-text-3/Packages/User/Sass.sublime-settings'),
    ('JavaScript.sublime-settings',
     '.config/sublime-text-3/Packages/User/JavaScript.sublime-settings'),
    ('JSON.sublime-settings',
     '.config/sublime-text-3/Packages/User/JSON.sublime-settings'),
    ('Python.sublime-settings',
     '.config/sublime-text-3/Packages/User/Python.sublime-settings'),
]

for item in files:
    if isinstance(item, tuple):
        ITEM_NAME = item[0]
        HOME_COPY = join(HOME_DIR, item[1])
    else:
        ITEM_NAME = item
        HOME_COPY = join(HOME_DIR, item)

    if isdir(ITEM_NAME):
        if exists(HOME_COPY):
            rmtree(HOME_COPY)
        copytree(ITEM_NAME, HOME_COPY)
    else:
        copy(ITEM_NAME, HOME_COPY)


def source(filename, dest):
    SOURCE = 'source ~/{filename}'.format(filename=filename)
    with open(join(HOME_DIR, '{dest}'.format(dest=dest)), mode='r') as fp:
        content = fp.read()
    if SOURCE not in content:
        with open(join(HOME_DIR, '{dest}'.format(dest=dest)), mode='a') as fp:
            fp.write('\n' + SOURCE + '\n')

source('.mybashrc', '.bashrc')
source('.mybash_profile', '.bash_profile')
