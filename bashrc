#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# PS1='[\u@\h \W]\$ '
PS1='\[\e[1;32m\][\u@\h \W]\$\[\e[0m\] '

alias ls='ls -F'
alias halt='sudo halt'
alias reboot='sudo reboot'
alias list='ls -FhAls | less'
alias mv='mv -i'
alias cp='cp -i'

tmux attach || tmux
exit
