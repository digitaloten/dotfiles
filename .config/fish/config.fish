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

# abbr for zoxide interactive
abbr z  "z"
abbr zx "zi"
abbr zz "z -"

# Replace cat with batcat
abbr cat     "bat --plain"
abbr bathelp "bat --plain --language=help"

function belp
    $argv --help 2>&1 | bathelp
end

# Replace default ls command
abbr ls "exa -F"

# Some more ls abbrs
abbr l  "ls -l"
abbr la "ls -a"
abbr ll "ls -al"

# I want v to open vi and vi to open vim
abbr v       "nvim"
abbr vd      "nvim -d"
abbr vi      "nvim"
abbr vim     "nvim"
abbr vimdiff "nvim -d"

# abbr g to git (saves a few key strokes)
abbr g  "git"
abbr gg "git status"

# abbr for make to m (save a few key strokes)
# as well as make sure to use the max threads available
abbr m    "make -j (nproc)"
abbr make "make -j (nproc)"

# abbr for quiting the command line
abbr :q  "exit"
abbr :qa "exit"
abbr :wq "exit"
abbr q   "exit"
abbr qa  "exit"
abbr wq  "exit"

# Load fzf
fzf_key_bindings

# Load zoxide
zoxide init fish | source

# Load starship prompt
starship init fish | source
