sudo apt-get update
# We install python because Ubuntu 18.04 does not come with
# Python 2.7 installed by default
sudo apt-get install -y git build-essential cmake python

mkdir -p ~/devel
cd ~/devel
git clone https://github.com/jpmelos/dotfiles
cd dotfiles
python dotfiles.py
