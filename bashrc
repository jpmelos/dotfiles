#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# PS1='[\u@\h \W]\$ '
PS1='\[\e[1;32m\][\u@\h \W]\$\[\e[0m\] '

alias halt='sudo halt'
alias reboot='sudo reboot'
# alias ls='ls --color=auto'
alias ls='ls -F'
