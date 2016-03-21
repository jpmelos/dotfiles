from subprocess import run as proc_run, DEVNULL, PIPE
from shlex import split
from shutil import copy, copytree, rmtree
from os import getenv, chdir
from os.path import dirname, abspath, isdir, join, exists


HOME_DIR = getenv('HOME')
BASE_DIR = dirname(abspath(__file__))


def run(command, *args, **kwargs):
        return proc_run(split(command), stdout=PIPE, stderr=DEVNULL, universal_newlines=True, *args, **kwargs)


def source(filename):
        SOURCE = 'source ~/.my{filename}'.format(filename=filename)
        with open(join(HOME_DIR, '.{filename}'.format(filename=filename)), mode='r') as fp:
                content = fp.read()
        if SOURCE not in content:
                with open(join(HOME_DIR, '.{filename}'.format(filename=filename)), mode='a') as fp:
                        fp.write('\n' + SOURCE + '\n')


run('git pull')
run('git submodule init')
run('git submodule update')

ls = run('git ls-tree --name-only HEAD')
files = ls.stdout.strip().split('\n')

for item in files:
        if isdir(item):
                HOME_COPY = join(HOME_DIR, item)
                if exists(HOME_COPY):
                        rmtree(HOME_COPY)
                copytree(item, HOME_COPY)
        else:
                copy(item, HOME_DIR)

source('bashrc')
source('profile')
