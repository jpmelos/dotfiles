# Raspberry Pi Setup Guide

## 1. Update the System

```bash
sudo apt-get --allow-releaseinfo-change update
sudo apt-get -y --allow-downgrades dist-upgrade
sudo apt-get -y autoremove
sudo apt-get -y clean
```

## 2. Install Required Software

```bash
sudo apt install curl wget git iptables-persistent openresolv wireguard transmission-daemon ca-certificates gpg jq starship stow fzf tmux npm chromium-browser sqlite3 libsqlite3-dev delta ffmpeg
git clone https://github.com/hyperupcall/autoenv ~/.autoenv
curl -LsSf https://astral.sh/uv/install.sh | sudo env UV_INSTALL_DIR=/usr/local/bin sh
uv --version
curl -sS https://downloads.1password.com/linux/keys/1password.asc |
	sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg &&
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" |
	sudo tee /etc/apt/sources.list.d/1password.list &&
	sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/ &&
	curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol |
	sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol &&
	sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22 &&
	curl -sS https://downloads.1password.com/linux/keys/1password.asc |
	sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg &&
	sudo apt update && sudo apt install 1password-cli
curl -LsSf https://repo.plex.tv/scripts/setupRepo.sh | sudo bash
sudo npm install -g agent-browser
```

Download the latest Neovim from GitHub and copy it onto Raspberry Pi, into
`~/apps`.

```
cd ~/apps
tar -xzf nvim.tar.gz
rm nvim.tar.gz
cd ~/bin
ln -s ../apps/nvim-linux-arm64/bin/nvim nvim
```

Download the latest Crystal compiler from GitHub and copy it onto Raspberry Pi,
into `~/apps`.

```
cd ~/apps
tar -xzf crystal.tar.gz --strip-components=1
rm crystal.tar.gz
cd ~/bin
ln -s ../apps/nvim-linux-arm64/bin/crystal crystal
ln -s ../apps/nvim-linux-arm64/bin/shards shards
```

## 3. Sign In to 1Password

```bash
eval $(op signin)
```

## 4. Get GPG Key from 1Password

```bash
op item get "PGP/GPG Key" --fields notesPlain --reveal --format json |
	jq -r .value |
	gpg --import
gpg --list-secret-keys
```

## 5. Clone Dotfiles and Link with `stow`

```bash
mkdir -p ~/devel
cd ~/devel
git clone git@github.com:jpmelos/dotfiles.git
cd dotfiles
rm ~/.bashrc
stow .
```

Load the new shell configuration (puts `~/bin` and `~/.local/bin` on PATH):

```bash
source ~/.bash_profile
```

Fetch the local configuration from 1Password (needs the sign-in from section
3):

```bash
jc fetch
```

This creates `~/config.json` with mode 600.

## 6. Create VPN Bypass Group

Create a new group for processes that will be allowed to bypass the VPN:

```bash
sudo groupadd -g 2727 vpn-bypass
```

The Telegram bot is the process that uses this bypass. Its unit
(`references/telegram_bot/telegram-bot.service`) sets `Group=vpn-bypass`.

## 7. Configure iptables

Copy iptables rules from dotfiles (`references/rpi/iptables/rules.v{4,6}`).
Adjust IP address of VPN server as necessary. Keep the endpoint in step with
the `Endpoint` in `/etc/wireguard/wg0.conf`. A stale address drops the
handshake and kills the tunnel.

```bash
sudo cp references/rpi/iptables/rules.v4 /etc/iptables/rules.v4
sudo cp references/rpi/iptables/rules.v6 /etc/iptables/rules.v6
```

Apply the rules:

```bash
sudo iptables-restore </etc/iptables/rules.v4
sudo ip6tables-restore </etc/iptables/rules.v6
```

## 8. Mount External Volume

Create the external volume mount point:

```bash
sudo mkdir -p /external
```

Check connected volumes:

```bash
sudo blkid
```

Attach the external HD and check what the new volume is:

```bash
sudo blkid
```

If you need to re-format:

```bash
sudo mkfs.ext4 -m 0 -L "External SSD" /dev/sda1
```

Add the following line to `/etc/fstab`:

```bash
sudo nvim /etc/fstab
```

```fstab
UUID=<UUID>  /external  ext4  defaults,noatime,nofail  0  2
```

Mount the new volume:

```bash
sudo systemctl daemon-reload
sudo mount -a
sudo chown jpmelos:jpmelos -R /external
chmod -R a+rwX /external
```

## 9. Configure WireGuard VPN

Get a device configuration from AirVPN and add these lines to the `[Interface]`
section:

```ini
[Interface]
…
PostUp = ip rule add fwmark 2727 table 2727
PostUp = ip route add default via 192.168.42.1 dev eth0 table 2727
PostDown = ip rule del fwmark 2727 table 2727
PostDown = ip route del default via 192.168.42.1 dev eth0 table 2727
```

Put it in `/etc/wireguard/wg0.conf`.

Configure it to always run:

```bash
sudo systemctl enable wg-quick@wg0.service
sudo systemctl daemon-reload
sudo systemctl start wg-quick@wg0
```

## 10. Configure Transmission

Stop the service:

```bash
sudo service transmission-daemon stop
```

Copy the settings file from the dotfiles repo to the config path:

```bash
sudo cp references/rpi/transmission-daemon-settings.json /etc/transmission-daemon/settings.json
sudo chown root:root /etc/transmission-daemon/settings.json
```

Run the service again:

```bash
sudo service transmission-daemon start
```

Go into the web UI. Verify that all looks right. Verify that the port is open
via AirVPN website.

## 11. Run Telegram Bot (Bypasses VPN)

The bot runs as user `telegram_bot` with primary group `vpn-bypass` (see
section 6). This marks its packets for the public Internet route. The unit file
already sets both. A dedicated user isolates the bot token and configuration.
Only `telegram_bot` (and root) can read them. The bot then resolves secrets
with `jc get` without human approval. The VPN replaces `/etc/resolv.conf` with
VPN-only resolvers. Bypassed traffic cannot reach those resolvers. The unit
bind-mounts `/etc/resolv.conf.bypass` over `/etc/resolv.conf`.

Create the user first (after section 6, so the `vpn-bypass` group exists):

```bash
sudo useradd -m -s /bin/bash telegram_bot
id telegram_bot
```

Give the bot its own copy of the dotfiles. The bot has no GitHub access. Copy
from your checkout in section 5 instead of cloning:

```bash
sudo mkdir -p /home/telegram_bot/devel
sudo cp -a /home/jpmelos/devel/dotfiles /home/telegram_bot/devel/dotfiles
sudo chown -R telegram_bot:telegram_bot /home/telegram_bot/devel
sudo -u telegram_bot -H bash -c 'cd ~/devel/dotfiles && rm -f ~/.bashrc && stow -R .'
```

After changes to the code or the configuration, run `update_telegram_bot`. It
pulls the dotfiles, refreshes `~/config.json`, syncs both to the bot user,
refreshes the service unit when it changed, and restarts the bot.

Copy your fetched configuration from section 5. The bot only runs `jc get`:

```bash
sudo install -o telegram_bot -g telegram_bot -m 600 /home/jpmelos/config.json /home/telegram_bot/config.json
```

Create the service account token file. In 1Password, create a service account
with read access to each vault named in the `op://` refs of `config.json`. Save
only the token in the file, with no key name and no extra lines:

```bash
sudo -u telegram_bot -H bash -c 'umask 077; cat > ~/op_service_account_token.txt'
```

Paste the token and press Enter. Then press Ctrl-D. Verify permissions. Only
`telegram_bot` can read either file:

```bash
sudo stat -c '%a %U:%G %n' /home/telegram_bot/config.json /home/telegram_bot/op_service_account_token.txt
```

Both lines must show `600 telegram_bot:telegram_bot`.

Create that file with clearnet resolvers first:

```bash
printf 'nameserver 192.168.42.1\nnameserver 1.1.1.1\n' | sudo tee /etc/resolv.conf.bypass
sudo chown root:root /etc/resolv.conf.bypass
sudo chmod 644 /etc/resolv.conf.bypass
```

Install and start the unit:

```bash
sudo cp ~/devel/dotfiles/references/telegram_bot/telegram-bot.service /etc/systemd/system/
sudo chown root:root /etc/systemd/system/telegram-bot.service
sudo systemctl daemon-reload
sudo systemctl enable --now telegram-bot
```

Verify:

```bash
sudo systemctl status telegram-bot
sudo journalctl -u telegram-bot -e
```
