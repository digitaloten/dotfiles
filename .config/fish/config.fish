#!/usr/bin/env fish
# No greeting text for now
set fish_greeting

# Set some stuff for out path
fish_add_path -g ~/.local/bin

# Set default editor to vim
set -Ux EDITOR "vim"

# Setup our default FZF command
set -Ux FZF_DEFAULT_COMMAND "rg --files --hidden -g '!.git'"
set -Ux FZF_CTRL_T_COMMAND  "$FZF_DEFAULT_COMMAND"
set -Ux FZF_DEFAULT_OPTS    "--height 30%"

# Replace default ls command
alias ls="exa -F"

# some more ls aliases
alias l='ls -l'
alias ll='ls -al'
alias la='ls -a'

# I want v to open vi and vi to open vim
alias v="nvim"
alias vi="nvim"
alias vim="nvim"
alias vimdiff="nvim -d"

# Alias make to use max cores/threads
alias make='make -j (nproc)'
