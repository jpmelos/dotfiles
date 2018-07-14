sudo apt-get update
sudo apt-get install -y \
    gnome-shell build-essential cmake git vim \
    \
    python python-dev python3 python3-dev \
    libreadline-dev libncursesw5-dev libssl-dev \
    libssl1.0-dev libgdbm-dev libsqlite3-dev \
    libbz2-dev liblzma-dev tk-dev libdb-dev \
    zlib1g-dev \
    \
    openvpn network-manager-openvpn-gnome

# Configure GDM to use vanilla Gnome colors and branding
sudo update-alternatives --set gdm3.css /usr/share/gnome-shell/theme/gnome-shell.css

mkdir -p ~/devel
cd ~/devel
git clone https://github.com/jpmelos/dotfiles
cd dotfiles/scripts
python dotfiles.py
