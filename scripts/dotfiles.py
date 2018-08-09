from collections import namedtuple
from io import StringIO
import contextlib
import importlib
import os
import re
import shlex
import shutil
import subprocess
import sys


class Exit(Exception):
    pass


Version = namedtuple("Version", ["major", "minor", "revision"])

information = {
    'github_token': None,
    'ssh_key_title': None,
}
ssh_key = None


def create_dir(dir_name):
    os.makedirs(dir_name, exist_ok=True)


def delete_dir(dir_name):
    if os.path.isdir(dir_name) and not os.path.islink(dir_name):
        shutil.rmtree(dir_name)


@contextlib.contextmanager
def change_dir(dir_name):
    old_dir = os.getcwd()
    os.chdir(dir_name)
    try:
        yield
    finally:
        os.chdir(old_dir)


def detect_os():
    os_regex = re.compile(r'^NAME="?(?P<name>\w+)"?$')

    name_found = None
    with open("/etc/os-release") as fp:
        lines = fp.read().split("\n")
    for line in lines:
        match = os_regex.match(line)
        if match:
            name_found = match.group("name")
            break

    if name_found in ["Ubuntu", "Fedora"]:
        return name_found

    raise Exception("Can't detect the OS")


def run(command, *args, **kwargs):
    completed_process = subprocess.run(
        shlex.split(command), universal_newlines=True, *args, **kwargs
    )
    completed_process.check_returncode()
    return completed_process


def run_for_output(command):
    return run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE).stdout


def git_clone(repo, dest=""):
    run("git clone {} {}".format(repo, dest))


def append_to_file(line, dest, not_found_ok=False):
    if os.path.exists(dest):
        with open(dest, mode="r") as fp:
            content = fp.read()
        if line.strip() not in content:
            with open(dest, mode="a") as fp:
                fp.write(line)
    else:
        if not not_found_ok:
            raise Exception("{} not found".format(dest))


def source(filename, dest, not_found_ok=False):
    source_line = "\nsource ~/{filename}\n".format(filename=filename)
    dest_file = os.path.join(home_dir, dest)
    append_to_file(source_line, dest_file, not_found_ok=not_found_ok)


def get_latest_version(versions, version_regex, for_minors=None):
    valid_versions = []
    for version in versions:
        match = version_regex.match(version)
        if match:
            valid_versions.append(
                Version(
                    int(match.group("major")),
                    int(match.group("minor")),
                    int(match.group("revision")),
                )
            )

    if not for_minors:
        return max(valid_versions)

    versions = {}
    for version in valid_versions:
        minor = (version.major, version.minor)
        if minor not in for_minors:
            continue

        revision = version
        if minor not in versions or versions[minor] < revision:
            versions[minor] = revision
    return versions.values()


detected_os = detect_os()

home_dir = os.path.expanduser("~")
devel_dir = os.path.join(home_dir, "devel")
dotfiles_dir = os.path.join(devel_dir, "dotfiles")


def get_information():
    for key, default in information.items():
        prompt = (
            key
            if default is None else
            '{} [{}]'.format(key, default)
        )
        information[key] = input('{} = '.format(prompt))


def _install_ubuntu_packages():
    ubuntu_packages = [
        "gnome-shell",
        "build-essential",
        "cmake",
        "git",
        "vim",
        "openvpn",
        "network-manager-openvpn-gnome",
        "python",
        "python-dev",
        "python3",
        "python3-dev",
        "libreadline-dev",
        "libncursesw5-dev",
        "libssl-dev",
        "libgdbm-dev",
        "libsqlite3-dev",
        "libbz2-dev",
        "liblzma-dev",
        "tk-dev",
        "libdb-dev",
        "zlib1g-dev",
        "libffi-dev",
    ]

    run("sudo apt-get update")
    run("sudo apt-get install -y {}".format(" ".join(ubuntu_packages)))


def _install_fedora_packages():
    fedora_packages = [
        "gcc",
        "cmake",
        "git",
        "vim",
        "python2",
        "python2-devel",
        "python3",
        "python3-devel",
        "readline-devel",
        "ncurses-devel",
        "openssl-devel",
        "gdbm-devel",
        "sqlite-devel",
        "sqlite2-devel",
        "zlib-devel",
        "bzip2-devel",
        "tk-devel",
        "libdb-devel",
        "libffi-devel",
    ]

    run("sudo dnf install -y {}".format(" ".join(fedora_packages)))


def install_packages():
    package_installers = {
        "Ubuntu": _install_ubuntu_packages,
        "Fedora": _install_fedora_packages,
    }
    package_installers[detected_os]()


def _setup_ubuntu():
    pass


def _setup_fedora():
    pass


def setup_os():
    os_setup_functions = {"Ubuntu": _setup_ubuntu, "Fedora": _setup_fedora}
    os_setup_functions[detected_os]()


def create_devel_dir():
    create_dir(devel_dir)
    os.chdir(devel_dir)


def _generate_ssh_key():
    global ssh_key

    key_path = os.path.join(home_dir, '.ssh', 'id_rsa.pub')
    if not os.path.exists(key_path):
        run('ssh-keygen -N ""')
    with open(key_path, 'r') as key:
        ssh_key = key.read().strip()


def _send_ssh_key_to_github():
    ssh_key_title = information['ssh_key_title']

    run('python3 -m pip install --user --upgrade pygithub')

    importlib.invalidate_caches()
    Github = importlib.import_module('github').Github

    gh = Github(information['github_token'])

    existing_keys = gh.get_user().get_keys()
    for key in existing_keys:
        if key.title == ssh_key_title:
            key.delete()
            break

    gh.get_user().create_key(
        information['ssh_key_title'],
        ssh_key,
    )


def _send_ssh_key_to_gitlab():
    pass


def _send_ssh_key_to_bitbucket():
    pass


def broadcast_ssh_keys():
    _generate_ssh_key()
    _send_ssh_key_to_github()
    _send_ssh_key_to_gitlab()
    _send_ssh_key_to_bitbucket()


def add_known_ssh_hosts():
    known_hosts_path = os.path.join(home_dir, ".ssh", "known_hosts")
    key_filenames = ["github.key", "gitlab.key", "bitbucket.key"]

    if not os.path.exists(known_hosts_path):
        create_dir(os.path.dirname(known_hosts_path))
        with open(known_hosts_path, "w+"):
            # Just need to create the file
            pass

    for filename in key_filenames:
        path = os.path.join(devel_dir, "references", filename)
        with open(path, "r") as key_file:
            keys = key_file.read().split("\n")
        for key in keys:
            append_to_file("{}\n".format(key), known_hosts_path)


def clone_dotfiles():
    dotfiles_repo = "git@github.com:jpmelos/dotfiles"

    if not os.path.exists(dotfiles_dir):
        git_clone(dotfiles_repo, dotfiles_dir)


def copy_configuration_files_and_dirs():
    dotfiles_list = [
        ("gitconfig", ".gitconfig"),
        ("gitignore-global", ".gitignore"),
        ("localserver.conf", ".localserver.conf"),
        ("mybashrc", ".mybash_profile"),
        ("mybashrc", ".mybashrc"),
        ("myprofile", ".myprofile"),
        ("tmux.conf", ".tmux.conf"),
        ("vimrc", ".vimrc"),
    ]

    for item in dotfiles_list:
        if isinstance(item, tuple):
            source = item[0]
            destination = item[1]
        elif isinstance(item, str):
            source = item
            destination = item
        else:
            raise TypeError("Items in 'files' must be strings or tuples")

        item_path = os.path.join(dotfiles_dir, "dotfiles", source)
        home_path = os.path.join(home_dir, destination)

        if os.path.lexists(home_path):
            if os.path.isdir(home_path) and not os.path.islink(home_path):
                shutil.rmtree(home_path)
            else:
                os.remove(home_path)

        create_dir(os.path.dirname(home_path))
        os.symlink(item_path, home_path)


def source_dotfiles():
    source(".myprofile", ".profile", not_found_ok=True)
    source(".mybashrc", ".bashrc", not_found_ok=True)
    source(".mybash_profile", ".bash_profile", not_found_ok=True)


def prepare_vim():
    vim_dir = os.path.join(home_dir, ".vim")
    vim_subdirs = ["backup", "swap", "undo"]
    vundle_repo = "https://github.com/gmarik/Vundle"
    vundle_dir = os.path.join(home_dir, ".vim/bundle/Vundle.vim")

    for directory in vim_subdirs:
        create_dir(os.path.join(vim_dir, directory))

    if not os.path.exists(vundle_dir):
        git_clone(vundle_repo, vundle_dir)
        run("vim +PluginInstall +qa")
        # After invoking Vim, sometimes the terminal gets garbled.
        # See if calling 'reset' solves the issue. This only happened
        # in Fedora so far.
        with change_dir(os.path.join(vim_dir, "bundle", "YouCompleteMe")):
            run("python install.py")


def get_git_prompt_and_autocompletion():
    git_version_regex = re.compile(r"^git version (?P<version>\d+\.\d+\.\d+)$")
    git_file_path = (
        "https://raw.githubusercontent.com/git/git/v{}/contrib/completion/{}"
    )
    git_files = ["git-completion.bash", "git-prompt.sh"]

    output = run_for_output("git --version")
    match = git_version_regex.match(output)
    version = match.group("version")

    for file in git_files:
        file_path = git_file_path.format(version, file)
        file_contents = run_for_output("wget -qO - {}".format(file_path))
        with open(os.path.join(home_dir, ".{}".format(file)), "w") as fp:
            fp.write(file_contents)


def install_pyenv():
    pyenv_repo = "https://github.com/pyenv/pyenv"
    pyenv_virtualenv_repo = "https://github.com/pyenv/pyenv-virtualenv"
    pyenv_dir = os.path.join(home_dir, ".pyenv")
    pyenv_virtualenv_dir = os.path.join(pyenv_dir, "plugins", "pyenv-virtualenv")

    pyenv_version_regex = re.compile(
        r"^v(?P<major>\d+)\.(?P<minor>\d+)\.(?P<revision>\d+)$"
    )
    python_version_regex = re.compile(
        r"^(?P<major>\d+)\.(?P<minor>\d+)\.(?P<revision>\d+)$"
    )

    if not os.path.exists(pyenv_dir):
        git_clone(pyenv_repo, pyenv_dir)
        git_clone(pyenv_virtualenv_repo, pyenv_virtualenv_dir)
        if detected_os in ["Ubuntu", "Fedora"]:
            delete_dir(os.path.join(home_dir, ".local", "bin"))
            delete_dir(os.path.join(home_dir, ".local", "lib"))

    with change_dir(pyenv_dir):
        output = run_for_output("git tag")
        latest_pyenv_version = get_latest_version(
            output.split("\n"), pyenv_version_regex
        )
        latest_pyenv_version = "v{}.{}.{}".format(
            latest_pyenv_version.major,
            latest_pyenv_version.minor,
            latest_pyenv_version.revision,
        )

    with change_dir(pyenv_virtualenv_dir):
        output = run_for_output("git tag")
        latest_pyenv_virtualenv_version = get_latest_version(
            output.split("\n"), pyenv_version_regex
        )
        latest_pyenv_virtualenv_version = "v{}.{}.{}".format(
            latest_pyenv_virtualenv_version.major,
            latest_pyenv_virtualenv_version.minor,
            latest_pyenv_virtualenv_version.revision,
        )

    python_versions_dir = os.path.join(
        pyenv_dir, "plugins", "python-build", "share", "python-build"
    )
    with change_dir(python_versions_dir):
        output = run_for_output("ls")
        latest_python_versions = get_latest_version(
            output.split("\n"),
            python_version_regex,
            for_minors=((2, 7), (3, 5), (3, 6), (3, 7)),
        )
        latest_python_versions = [
            "{}.{}.{}".format(version.major, version.minor, version.revision)
            for version in latest_python_versions
        ]

    run(
        "bash dotfiles/scripts/install_pyenv.sh {} {} {}".format(
            latest_pyenv_version,
            latest_pyenv_virtualenv_version,
            " ".join(latest_python_versions),
        )
    )


def list_additional_steps():
    # TODO: Automate these steps
    print("Additional steps: ")
    print(
        '* Silence the terminal bell by adding "set bell-style none" to '
        "your /etc/inputrc."
    )
    print(
        "* Configure your default VPN by adding the files needed in a "
        "subfolder in ~/vpns and renaming the start file to conf.conf, "
        "having a bootstrap file as start_vpn.sh and a destruction "
        "file as stop_vpn.sh."
    )
    print("Restart your terminal.")


# TODO: Verify each step and see if they work when run consecutive times,
# and after a long time when versions changed and need to be updated or
# reinstalled.
steps = [
    get_information,
    install_packages,
    setup_os,
    create_devel_dir,
    broadcast_ssh_keys,
    add_known_ssh_hosts,
    clone_dotfiles,
    copy_configuration_files_and_dirs,
    source_dotfiles,
    prepare_vim,
    get_git_prompt_and_autocompletion,
    install_pyenv,
    # TODO: Install Docker
    # TODO: Install VLC media player
    # TODO: Install Chrome
    # TODO: Install PyCharm
    # TODO: Install VPN
    list_additional_steps,
]


def run_steps():
    for step_function in steps:
        try:
            step_function()
        except Exit:
            break


if __name__ == "__main__":
    run_steps()
