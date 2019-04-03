dotfiles
========

To install these dotfiles on **Ubuntu 18.04**, add a `~/.dotfiles_config` file to your home folder. The format expected is::

    [github]
    ssh_key_title =
    token =

    [bitbucket]
    ssh_key_title =
    username =
    token =

    [gitlab]
    ssh_key_title =
    token =

    [mullvad]
    account =
    server =

    [aws]
    aws_access_key_id =
    aws_secret_access_key =

And then run::

    wget -qO - https://raw.githubusercontent.com/jpmelos/dotfiles/master/scripts/dotfiles.py > dotfiles.py
    python3 dotfiles.py
    rm dotfiles.py
