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
sudo apt install curl wget git neovim iptables-persistent openresolv wireguard transmission-daemon ca-certificates gpg jq starship stow fzf tmux
git clone https://github.com/hyperupcall/autoenv ~/.autoenv
curl -LsSf https://astral.sh/uv/install.sh | sh
curl -sS https://downloads.1password.com/linux/keys/1password.asc \
    | sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
    | sudo tee /etc/apt/sources.list.d/1password.list \
    && sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/ \
    && curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol \
    | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol \
    && sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22 \
    && curl -sS https://downloads.1password.com/linux/keys/1password.asc \
    | sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg \
    && sudo apt update && sudo apt install 1password-cli
```

## 3. Sign In to 1Password

```bash
eval $(op signin)
```

## 4. Get GPG Key from 1Password

```bash
op item get "PGP/GPG Key" --fields notesPlain --reveal --format json \
    | jq -r .value \
    | gpg --import
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

Copy iptables rules from dotfiles (`references/iptables-rpi/rules.v{4,6}`).
Adjust IP address of VPN server as necessary.

```bash
sudo cp references/iptables-rpi/rules.v4 /etc/iptables/rules.v4
sudo cp references/iptables-rpi/rules.v6 /etc/iptables/rules.v6
```

Apply the rules:

```bash
sudo iptables-restore < /etc/iptables/rules.v4
sudo ip6tables-restore < /etc/iptables/rules.v6
```

Check that rules are in effect:

```bash
sudo iptables -vnL
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
sudo chown jpmelos:jpmelos -R /external/
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
sudo cp references/rpi/transmission-daemon-settings.json .config/transmission-daemon/settings.json
```

Run the service again:

```bash
sudo service transmission-daemon start
```

Go into the web UI. Verify that all looks right. Verify that the port is open
via AirVPN website.

## 11. Install Plex

Install Plex via APT:

```bash
curl -LsSf https://repo.plex.tv/scripts/setupRepo.sh | sudo bash
```

Start the service:

```bash
sudo service plexmediaserver start
```

## 12. Run Telegram Bot (Bypasses VPN)

The bot runs under systemd with primary group `vpn-bypass` (see section 6),
which marks its packets for the public Internet route. The unit file already
sets this.

Install and start the unit:

```bash
sudo cp ~/devel/dotfiles/references/telegram_bot/telegram-bot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now telegram-bot
```

Verify:

```bash
systemctl status telegram-bot
journalctl -u telegram-bot -e
```
