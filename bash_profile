source ~/.bashrc

if [[ $(tty) = /dev/tty1 ]]; then
	startx
	logout
fi
