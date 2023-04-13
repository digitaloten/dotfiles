# Set default editor to vim
export EDITOR="vim"

# Setup our default FZF command
export FZF_DEFAULT_COMMAND="rg --files --hidden -g '!.git' | devicon-lookup"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS="--height 30%"

if status is-interactive
    # Commands to run in interactive sessions can go here
end

alias ls=exa
