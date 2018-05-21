sudo apt-get update
# We install python because Ubuntu 18.04 does not come with
# Python 2.7 installed by default
sudo apt-get install -y \
    git build-essential cmake vim gnome-shell \
    python python-dev python3 python3-dev

# Configure GDM to use vanilla Gnome colors and branding
sudo update-alternatives --set gdm3.css /usr/share/gnome-shell/theme/gnome-shell.css

mkdir -p ~/devel
cd ~/devel
git clone https://github.com/jpmelos/dotfiles
cd dotfiles
python dotfiles.py
