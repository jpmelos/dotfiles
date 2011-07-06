PS1='\[\e[1;32m\][\u@\h \W]\$\[\e[0m\] '
EDITOR=/usr/bin/vim

alias ls='ls -F'
alias list='ls -Fhls | less'
alias reboot='sudo reboot'
alias halt='sudo halt'
alias cp='cp -i'
alias mv='mv -i'
alias cal='cal -3'

umask 077

function setperm
{
	find . -type d -exec chmod 700 {} \;
	find . -type f -exec chmod 600 {} \;
}

# If not in /dev/tty1 and not in tmux already, call tmux
if [[ $(tty) != /dev/tty1 && -z $TMUX ]]; then
	tmux || tmux attach
	exit
fi

# If in tmux
if [[ -n $TMUX ]]; then
	export TERM=screen-256color
fi
