sudo apt-get update
# We install python because Ubuntu 18.04 does not come with
# Python 2.7 installed by default
sudo apt-get install -y \
    gnome-shell build-essential cmake git vim \
    python python-dev python3 python3-dev \
    libreadline-dev libncursesw5-dev libssl-dev \
    libssl1.0-dev libgdbm-dev libsqlite3-dev \
    libbz2-dev liblzma-dev tk-dev libdb-dev \
    zlib1g-dev

# Configure GDM to use vanilla Gnome colors and branding
sudo update-alternatives --set gdm3.css /usr/share/gnome-shell/theme/gnome-shell.css

mkdir -p ~/devel
cd ~/devel
git clone https://github.com/jpmelos/dotfiles
cd dotfiles
python dotfiles.py
