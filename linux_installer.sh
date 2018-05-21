sudo apt-get update
sudo apt-get install git build-essentials cmake

mkdir -p ~/devel
cd ~/devel
git clone https://github.com/jpmelos/dotfiles
cd dotfiles
python dotfiles.py
