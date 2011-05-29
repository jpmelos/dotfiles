# PS1='[\u@\h \W]\$ '
PS1='\[\e[1;32m\][\u@\h \W]\$\[\e[0m\] '

alias ls='ls -F'

if [[ -z $DISPLAY && $(tty) = /dev/tty1 ]]; then
	startx
	logout
fi
