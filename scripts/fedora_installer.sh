sudo dnf install \
    gcc cmake git vim \
    \
    python2 python2-devel \
    python3 python3-devel \
    readline-devel \
    ncurses-devel \
    openssl-devel \
    gdbm-devel \
    sqlite-devel \
    sqlite2-devel \
    zlib-devel \
    bzip2-devel \
    tk-devel \
    libdb-devel \
    libffi-devel

mkdir -p ~/devel
cd ~/devel
git clone https://github.com/jpmelos/dotfiles
cd dotfiles/scripts
python dotfiles.py
