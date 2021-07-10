#!/usr/bin/env python3.6
import base64
import contextlib
import json
import os
import re
import shlex
import shutil
import subprocess
import sys
from collections import namedtuple
from configparser import ConfigParser
from urllib.request import Request, urlopen

version = ".".join(map(str, sys.version_info[0:2]))
if version != "3.6":
    raise Exception(f"Must be using Python 3.6: detected {version}")

config = ConfigParser()
config_file_path = os.path.expanduser("~/.dotfiles_config")
if not config.read([config_file_path]):
    raise Exception("Did not find configuration file")


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


def run(command, check_errors=True, universal_newlines=True, *args, **kwargs):
    completed_process = subprocess.run(
        shlex.split(command),
        universal_newlines=universal_newlines,
        *args,
        **kwargs,
    )
    if check_errors:
        completed_process.check_returncode()
    return completed_process


def run_for_output(command, *args, **kwargs):
    return run(
        command,
        check_errors=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        *args,
        **kwargs,
    ).stdout.strip()


def run_for_output_b_stderr(command, *args, **kwargs):
    return run(
        command,
        check_errors=False,
        universal_newlines=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        *args,
        **kwargs,
    ).stderr


def git_clone(repo, dest=""):
    run("git clone {} {}".format(repo, dest))


def append_to_file(dest, line):
    with open(dest, mode="r") as fp:
        content = fp.read()
    if line.strip() not in content:
        with open(dest, mode="a") as fp:
            fp.write(line)


def get_latest_version(versions, version_regex, for_minors=None):
    Version = namedtuple("Version", ["major", "minor", "revision"])

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

        if minor not in versions or versions[minor] < version:
            versions[minor] = version

    return versions.values()


home_dir = os.path.expanduser("~")

devel_dir = os.path.join(home_dir, "devel")
bin_dir = os.path.join(home_dir, "bin")
ssh_dir = os.path.join(home_dir, ".ssh")

dotfiles_dir = os.path.join(devel_dir, "dotfiles")


def install_packages():
    os_packages = [
        # Shell
        "zsh",
        "tmux",
        # Entertainment
        "vlc",
        # Utils
        "gnome-calculator",
        "htop",
        "vim",
        "pdftk",
        "rar",
        "unrar",
        "sshfs",
        "deluge",
        "pavucontrol",
        "libcanberra-gtk-module",
        "libcanberra-gtk3-module",
        # Development tools
        "build-essential",
        "cmake",
        "ack",
        "git",
        # Fonts
        "ttf-mscorefonts-installer",
        "fonts-cantarell",
        "fonts-powerline",
        "lmodern",
        "ttf-aenigma",
        "ttf-georgewilliams",
        "ttf-bitstream-vera",
        "ttf-sjfonts",
        "fonts-tuffy",
        "tv-fonts",
        "fonts-inconsolata",
        # Networking
        "iptables-persistent",
        "net-tools",
        # Python dependencies
        "python3-dev",
        "libreadline-dev",
        "libncursesw5-dev",
        "libssl-dev",
        "libgdbm-dev",
        "libsqlite3-dev",
        "libpq-dev",
        "libbz2-dev",
        "liblzma-dev",
        "tk-dev",
        "libdb-dev",
        "zlib1g-dev",
        "libffi-dev",
    ]

    run("sudo apt-get update")
    run("sudo apt-get install -y {}".format(" ".join(os_packages)))


def _change_default_shell():
    run("sudo chsh -s /usr/bin/zsh")


def _disable_camera_shutter_on_screenshot():
    shutter_path = "/usr/share/sounds/freedesktop/stereo/camera-shutter.oga"
    if os.path.exists(shutter_path):
        print("Shutter file exists.")
        run(f"sudo rm {shutter_path}")
    else:
        print("Shutter file does not exist.")


def setup_os():
    _change_default_shell()
    _disable_camera_shutter_on_screenshot()


def create_devel_dir():
    create_dir(devel_dir)


def create_bin_dir():
    create_dir(bin_dir)


def _import_ssh_key():
    raise Exception


def _send_ssh_key_to_github(ssh_key):
    ssh_key_title = config["github"]["ssh_key_title"]
    authorization = "token {}".format(config["github"]["token"])
    headers = {
        "Authorization": authorization,
        "Content-Type": "application/json; charset=utf-8",
    }

    github_base_url = "https://api.github.com"
    keys_resource = "{}/user/keys".format(github_base_url)

    get_keys_req = Request(keys_resource, headers=headers)

    with urlopen(get_keys_req) as response:
        keys = json.loads(response.read().strip())
    for key in keys:
        local_relevant_key = ssh_key.split(" ")[1]
        remote_relevant_key = key["key"].split(" ")[1]
        if local_relevant_key == remote_relevant_key:
            return

    for key in keys:
        if key["title"] == ssh_key_title:
            delete_req = Request(key["url"], headers=headers, method="DELETE")
            urlopen(delete_req)
            break

    add_key_req = Request(
        keys_resource,
        data=json.dumps({"title": ssh_key_title, "key": ssh_key}).encode(),
        headers=headers,
        method="POST",
    )
    urlopen(add_key_req)


def _send_ssh_key_to_bitbucket(ssh_key):
    ssh_key_title = config["bitbucket"]["ssh_key_title"]
    username = config["bitbucket"]["username"]
    token = "{}:{}".format(username, config["bitbucket"]["token"])
    authorization = "Basic {}".format(
        base64.b64encode(token.encode()).decode()
    )
    headers = {
        "Authorization": authorization,
        "Content-Type": "application/json; charset=utf-8",
    }

    base_url = "https://api.bitbucket.org/2.0"
    keys_resource = "{}/users/{}/ssh-keys".format(base_url, username)

    get_keys_req = Request(keys_resource, headers=headers)

    with urlopen(get_keys_req) as response:
        keys = json.loads(response.read().strip())["values"]
    for key in keys:
        local_relevant_key = ssh_key.split(" ")[1]
        remote_relevant_key = key["key"].split(" ")[1]
        if local_relevant_key == remote_relevant_key:
            return

    for key in keys:
        if key["label"] == ssh_key_title:
            delete_req = Request(
                key["links"]["self"]["href"], headers=headers, method="DELETE"
            )
            urlopen(delete_req)
            break

    add_key_req = Request(
        keys_resource,
        data=json.dumps({"label": ssh_key_title, "key": ssh_key}).encode(),
        headers=headers,
        method="POST",
    )
    urlopen(add_key_req)


def _send_ssh_key_to_gitlab(ssh_key):
    ssh_key_title = config["gitlab"]["ssh_key_title"]
    authorization = config["gitlab"]["token"]
    headers = {
        "Private-Token": authorization,
        "Content-Type": "application/json; charset=utf-8",
    }

    base_url = "https://gitlab.com/api/v4"
    keys_resource = "{}/user/keys".format(base_url)

    get_keys_req = Request(keys_resource, headers=headers)

    with urlopen(get_keys_req) as response:
        keys = json.loads(response.read().strip())
    for key in keys:
        local_relevant_key = ssh_key.split(" ")[1]
        remote_relevant_key = key["key"].split(" ")[1]
        if local_relevant_key == remote_relevant_key:
            return

    for key in keys:
        if key["title"] == ssh_key_title:
            delete_req = Request(
                "{}/{}".format(keys_resource, key["id"]),
                headers=headers,
                method="DELETE",
            )
            urlopen(delete_req)
            break

    add_key_req = Request(
        keys_resource,
        data=json.dumps({"title": ssh_key_title, "key": ssh_key}).encode(),
        headers=headers,
        method="POST",
    )
    urlopen(add_key_req)


def broadcast_ssh_keys():
    ssh_key = _import_ssh_key()
    _send_ssh_key_to_github(ssh_key)
    _send_ssh_key_to_bitbucket(ssh_key)
    _send_ssh_key_to_gitlab(ssh_key)


def add_known_ssh_hosts():
    known_hosts_path = os.path.join(ssh_dir, "known_hosts")
    file_urls = (
        "https://raw.githubusercontent.com/"
        "jpmelos/dotfiles/master/references/{}"
    )
    key_filenames = ["github.key", "gitlab.key", "bitbucket.key"]

    if os.path.exists(known_hosts_path):
        with open(known_hosts_path, 'r') as fp:
            known_hosts = fp.read().split("\n")

    for filename in key_filenames:
        url = file_urls.format(filename)
        file_contents = run_for_output("wget -qO - {}".format(url))
        keys = file_contents.split("\n")
        for key in keys:
            stripped_key = key.strip()
            if stripped_key and stripped_key not in known_hosts:
                known_hosts.append(stripped_key)

    with open(known_hosts_path, 'w') as fp:
        fp.write('\n'.join(known_hosts))


def setup_zsh_theme():
    custom_themes_dir = os.path.join(home_dir, ".oh-my-zsh", "custom", "themes")
    spaceship_dir = os.path.join(custom_themes_dir, "")
    run(f"git clone https://github.com/jpmelos/spaceship-prompt.git {custom_themes_dir}/spaceship-prompt")
    run(f"ln -s {custom_themes_dir}/spaceship-prompt/spaceship.zsh-theme {custom_themes_dir}/themes/spaceship.zsh-theme")


def clone_dotfiles():
    dotfiles_repo = "git@github.com:jpmelos/dotfiles"
    if os.path.exists(dotfiles_dir):
        return

    git_clone(dotfiles_repo, dotfiles_dir)


def _resolve_gpg_keys_file_template():
    gpg_regex = re.compile(r"gpg: key (?P<key_name>[0-9A-Z]{16}):")
    gpg_keys_template = os.path.join(
        dotfiles_dir, "references", "gpg-keys.template"
    )
    gpg_keys_file = os.path.join(
        dotfiles_dir, "dotfiles", "gitconfigs", "gpg-keys"
    )

    gpg_key = base64.b64decode(config["gpg"]["gpg_key"].encode("utf-8"))
    output = (
        run_for_output_b_stderr("gpg --import", input=gpg_key)
        .decode("utf-8")
        .split("\n")[0]
    )
    gpg_key_name = gpg_regex.match(output).group("key_name")

    with open(gpg_keys_template) as fp:
        content = fp.read()
    with open(gpg_keys_file, "w") as fp:
        fp.write(content.replace("{gpg_key}", gpg_key_name))


def resolve_templates():
    _resolve_gpg_keys_file_template()


def copy_configuration_files_and_dirs():
    dotfiles_list = [
        ("gitconfig", ".gitconfig"),
        ("gitignore-global", ".gitignore"),
        ("gpg.conf", ".gnupg/gpg.conf"),
        ("localserver.conf", ".localserver.conf"),
        ("tmux.conf", ".tmux.conf"),
        ("vimrc", ".vimrc"),
        ("profile", ".profile"),
        ("zprofile", ".zprofile"),
        ("zshrc", ".zshrc"),
    ]

    for source, destination in dotfiles_list:
        item_path = os.path.join(dotfiles_dir, "dotfiles", source)
        home_path = os.path.join(home_dir, destination)

        if os.path.lexists(home_path):
            if os.path.isdir(home_path) and not os.path.islink(home_path):
                shutil.rmtree(home_path)
            else:
                os.remove(home_path)

        create_dir(os.path.dirname(home_path))
        os.symlink(item_path, home_path)


# How to backup and restore your terminal settings:
# https://askubuntu.com/a/967535
# To backup, run scripts/backup_terminal.sh from repository root
def set_terminal_settings():
    terminal_settings_path = os.path.join(
        dotfiles_dir, "references", "terminal_settings.txt"
    )
    with open(terminal_settings_path, "r") as fp:
        run("dconf load /org/gnome/terminal/", input=fp.read())


def prepare_vim():
    vim_dir = os.path.join(home_dir, ".vim")
    vim_subdirs = ["backup", "swap", "undo"]
    vundle_repo = "https://github.com/gmarik/Vundle"
    vundle_dir = os.path.join(home_dir, ".vim/bundle/Vundle.vim")

    for directory in vim_subdirs:
        create_dir(os.path.join(vim_dir, directory))

    if os.path.exists(vundle_dir):
        return

    git_clone(vundle_repo, vundle_dir)
    run("vim +PluginInstall +qa")


def install_pyenv():
    pyenv_repo = "https://github.com/pyenv/pyenv"
    pyenv_virtualenv_repo = "https://github.com/pyenv/pyenv-virtualenv"
    pyenv_dir = os.path.join(home_dir, ".pyenv")
    pyenv_virtualenv_dir = os.path.join(
        pyenv_dir, "plugins", "pyenv-virtualenv"
    )

    pyenv_version_regex = re.compile(
        r"^v(?P<major>\d+)\.(?P<minor>\d+)\.(?P<revision>\d+)$"
    )
    python_version_regex = re.compile(
        r"^(?P<major>\d+)\.(?P<minor>\d+)\.(?P<revision>\d+)$"
    )

    if not os.path.exists(pyenv_dir):
        git_clone(pyenv_repo, pyenv_dir)
        git_clone(pyenv_virtualenv_repo, pyenv_virtualenv_dir)
        delete_dir(os.path.join(home_dir, ".local", "bin"))
        delete_dir(os.path.join(home_dir, ".local", "lib"))

    with change_dir(pyenv_dir):
        run("git checkout master")
        run("git fetch --all")
        run("git pull")
        output = run_for_output("git tag")
        latest_pyenv_version = get_latest_version(
            output.split("\n"), pyenv_version_regex
        )
        latest_pyenv_version = "v{}.{}.{}".format(
            latest_pyenv_version.major,
            latest_pyenv_version.minor,
            latest_pyenv_version.revision,
        )
        run("git checkout {}".format(latest_pyenv_version))

    with change_dir(pyenv_virtualenv_dir):
        run("git checkout master")
        run("git fetch --all")
        run("git pull")
        output = run_for_output("git tag")
        latest_pyenv_virtualenv_version = get_latest_version(
            output.split("\n"), pyenv_version_regex
        )
        latest_pyenv_virtualenv_version = "v{}.{}.{}".format(
            latest_pyenv_virtualenv_version.major,
            latest_pyenv_virtualenv_version.minor,
            latest_pyenv_virtualenv_version.revision,
        )
        run("git checkout {}".format(latest_pyenv_virtualenv_version))

    python_versions_dir = os.path.join(
        pyenv_dir, "plugins", "python-build", "share", "python-build"
    )
    with change_dir(python_versions_dir):
        output = run_for_output("ls")
        latest_python_versions = get_latest_version(
            output.split("\n"),
            python_version_regex,
            for_minors=((3, 6), (3, 7), (3, 8), (3, 9)),
        )
        latest_python_versions = [
            "{}.{}.{}".format(version.major, version.minor, version.revision)
            for version in latest_python_versions
        ]

    run(
        "bash scripts/install_pyenv.sh {}".format(
            " ".join(latest_python_versions)
        )
    )


def install_poetry():
    poetry_install_file = "poetry.py"

    with change_dir(os.path.expanduser("~")):
        run(
            "wget -qO {} https://raw.githubusercontent.com/"
            "python-poetry/poetry/master/get-poetry.py".format(
                poetry_install_file
            )
        )
        run("chmod +x {}".format(poetry_install_file))
        run("python3 {}".format(poetry_install_file))
        run("rm {}".format(poetry_install_file))


def add_aws_credentials_file():
    aws_credentials_dir = os.path.join(os.path.expanduser("~"), ".aws")
    aws_credentials_file_path = os.path.join(
        aws_credentials_dir, "credentials"
    )

    create_dir(aws_credentials_dir)
    aws_credentials = ConfigParser()
    aws_credentials["default"] = config["aws"]
    with open(aws_credentials_file_path, "w") as fp:
        aws_credentials.write(fp)


def install_docker():
    docker_data_dir = os.sep + os.path.join("var", "lib", "docker")
    if os.path.exists(docker_data_dir):
        return

    docker_gpg_key_path = os.path.join(home_dir, "docker_repository_gpg_key")

    run("sudo apt-get update")
    run(
        "sudo apt-get -y install"
        " apt-transport-https ca-certificates curl software-properties-common"
    )
    run(
        "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o {}".format(
            docker_gpg_key_path
        )
    )
    run("sudo apt-key add {}".format(docker_gpg_key_path))
    os.remove(docker_gpg_key_path)

    ubuntu_release = run_for_output("lsb_release -cs")
    run(
        "sudo add-apt-repository "
        '"deb [arch=amd64] https://download.docker.com/linux/ubuntu '
        '{} stable"'.format(ubuntu_release)
    )
    run("sudo apt-get update")
    run("sudo apt-get -y install docker-ce")

    groups_database = run_for_output("getent group").split("\n")
    groups_components = [
        components.split(":") for components in groups_database
    ]
    groups = [component[0] for component in groups_components]
    if "docker" not in groups:
        run("sudo groupadd docker")
    run("sudo usermod -aG docker {}".format(os.getlogin()))


def install_network_configs():
    run("sudo mkdir -p {}".format(os.sep + os.path.join("etc", "iptables")))

    iptables_reference = os.path.join(dotfiles_dir, "references", "iptables")
    iptables_config_path = os.sep + os.path.join("etc", "iptables", "rules.v4")
    run("sudo cp {} {}".format(iptables_reference, iptables_config_path))

    ip6tables_reference = os.path.join(dotfiles_dir, "references", "ip6tables")
    ip6tables_config_path = os.sep + os.path.join(
        "etc", "iptables", "rules.v6"
    )
    run("sudo cp {} {}".format(ip6tables_reference, ip6tables_config_path))


def list_additional_steps():
    # TODO: Automate these steps
    print(  # noqa: T001
        """Additional steps:
* Install Dropbox
* Comment out "SendEnv LANG LC_*" in /etc/ssh/ssh_config
* Restart your computer."""
    )


def run_steps():
    steps = [
        install_packages,
        setup_os,
        create_devel_dir,
        create_bin_dir,
        broadcast_ssh_keys,
        add_known_ssh_hosts,
        setup_zsh_theme,
        clone_dotfiles,
        resolve_templates,
        copy_configuration_files_and_dirs,
        set_terminal_settings,
        prepare_vim,
        install_pyenv,
        install_poetry,
        add_aws_credentials_file,
        install_docker,
        install_network_configs,
        list_additional_steps,
    ]
    for step_function in steps:
        step_function()


if __name__ == "__main__":
    run_steps()
