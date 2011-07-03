# PS1='[\u@\h \W]\$ '
PS1='\[\e[1;32m\][\u@\h \W]\$\[\e[0m\] '

alias ls='ls -F'
alias halt='sudo halt'
alias reboot='sudo reboot'
alias list='ls -Fhls | less'
alias mv='mv -i'
alias cp='cp -i'

umask 077

if [[ -z $DISPLAY && $(tty) = /dev/tty1 ]]; then
	startx
	logout
fi
