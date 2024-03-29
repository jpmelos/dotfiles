# dotfiles

To install these dotfiles on **Pop!_OS 20.04**, add a `~/.dotfiles_config`. The format expected is:

```
[gpg]
gpg_key = Your GPG key base64-encoded.

[github]
ssh_key_title = The SSH key you need to add to GitHub for this computer.
token = Credential we can use to add the SSH key.

[bitbucket]
ssh_key_title = The SSH key you need to add to GitHub for this computer.
username = Credential we can use to add the SSH key.
token = Credential we can use to add the SSH key.

[gitlab]
ssh_key_title = The SSH key you need to add to GitHub for this computer.
token = Credential we can use to add the SSH key.

[aws]
aws_access_key_id = Your AWS credential.
aws_secret_access_key = Your AWS credential.
```

And then run:

```
wget -qO - https://raw.githubusercontent.com/jpmelos/dotfiles/master/scripts/dotfiles.py > dotfiles.py
wget -qO - https://raw.githubusercontent.com/jpmelos/dotfiles/master/scripts/install_pyenv.sh > install_pyenv.sh
python3 dotfiles.py
rm dotfiles.py install_pyenv.sh .dotfiles_config  # Clean up and delete config file as it contains secret information.
```
