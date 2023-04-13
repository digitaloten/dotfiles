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
set -Ux FZF_CTRL_T_OPTS     "--preview 'bat -n --color=always {}'"
set -Ux FZF_DEFAULT_OPTS    "--height 30%"

# Use BAT for our man pages
set -Ux MANPAGER "sh -c 'col -bx | bat -l man -p'"

# Alias for zoxide interactive
alias z  "z"
alias zx "zi"
alias zz "z -"

# Replace cat with batcat
alias cat "bat --plain"
alias bathelp='bat --plain --language=help'

function belp
    $argv --help 2>&1 | bathelp
end

# Replace default ls command
alias ls "exa -F"

# Some more ls aliases
alias l  "ls -l"
alias la "ls -a"
alias ll "ls -al"

# I want v to open vi and vi to open vim
alias v       "nvim"
alias vd      "nvim -d"
alias vi      "nvim"
alias vim     "nvim"
alias vimdiff "nvim -d"

# Alias g to git (saves a few key strokes)
alias g  "git"
alias gg "git status"

# Alias for make to m (save a few key strokes)
# as well as make sure to use the max threads available
alias m    "make -j (nproc)"
alias make "make -j (nproc)"

# Load fzf
fzf_key_bindings

# Load zoxide
zoxide init fish | source

# Load starship prompt
starship init fish | source
