#!/usr/bin/env bash

alias la="exa -a"
alias ls="exa"
alias ll="exa -lhg --git"
alias ld="exa -lahgD --git"
alias lt="exa --tree"
alias v="nvim"
alias cat="bat"
alias h="history"

export GPG_TTY=$(tty)

# super powers for CD command
export CDPATH=".:..:~:~/coding/personal:~/coding/inocan/open-source:~/coding/particle:~/coding/langler:~/coding/lifegadget:~/.config" 
