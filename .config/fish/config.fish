#!/usr/bin/env fish
# No greeting text for now
set fish_greeting

# Set default editor to vim
export EDITOR="vim"

# Set some stuff for out path
fish_add_path -g ~/.local/bin

# Setup our default FZF command
export FZF_DEFAULT_COMMAND="rg --files --hidden -g '!.git' | devicon-lookup"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS="--height 30%"

# Replace default ls command
alias ls="exa -F"

# some more ls aliases
alias l='ls -l'
alias ll='ls -al'
alias la='ls -a'

# I want v to open vi and vi to open vim
alias v=vim
alias vi=vim

# Alias make to use max cores/threads
alias make='make -j $(nproc)'
