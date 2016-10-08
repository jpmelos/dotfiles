#!/usr/bin/env python3.4

import os
import shutil


HOME_DIR = os.environ['HOME']
BASE_DIR = os.path.dirname(os.path.abspath(__file__))


files = [
    '.fonts',
    '.gitconfig',
    'localserver.conf',
    '.mybashrc',
    '.myprofile',
    ('.myprofile', '.mybash_profile'),
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
    ('PHP.sublime-settings',
     '.config/sublime-text-3/Packages/User/PHP.sublime-settings'),
    ('Shell-Unix-Generic.sublime-settings',
     '.config/sublime-text-3/Packages/User/Shell-Unix-Generic.sublime-settings'),
]

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


def source(filename, dest):
    SOURCE = 'source ~/{filename}'.format(filename=filename)
    dest_file = os.path.join(HOME_DIR, dest)
    if os.path.exists(dest_file):
        with open(dest_file, mode='r') as fp:
            content = fp.read()
        if SOURCE not in content:
            with open(dest_file, mode='a') as fp:
                fp.write('\n' + SOURCE + '\n')

source('.mybashrc', '.bashrc')
source('.myprofile', '.profile')
source('.mybash_profile', '.bash_profile')
