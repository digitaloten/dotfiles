# Set default editor to vim
export EDITOR="vim"

# Set some stuff for out path
export PATH="$PATH $HOME/.local/bin"

# Setup our default FZF command
export FZF_DEFAULT_COMMAND="rg --files --hidden -g '!.git' | devicon-lookup"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS="--height 30%"

# No greeting text for now
set fish_greeting

# Replace default ls command
alias ls="exa -F"

# some more ls aliases
alias l='ls -l'
alias ll='ls -al'
alias la='ls -a'
