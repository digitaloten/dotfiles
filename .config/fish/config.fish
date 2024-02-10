#!/usr/bin/env fish
# No greeting text for now
set fish_greeting

# Set some stuff for out path
fish_add_path -g ~/.local/bin
fish_add_path -g ~/.cargo/bin
fish_add_path -g /opt/homebrew/bin

# Set default editor to vim
set -gx EDITOR nvim

# Disable MANGOHUD by default
set -gx MANGOHUD 0

# Add makeflags
set -gx MAKEFLAGS "-j$(nproc)"

# Setup our default FZF command
set -gx FZF_DEFAULT_COMMAND "rg --files --hidden -g '!.git'"
set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set -gx FZF_CTRL_T_OPTS "--preview 'bat -n --color=always {}'"
set -gx FZF_DEFAULT_OPTS "--height 100%"

# for zoxide interactive
alias zx zi
alias zz "z -"

# Replace cat with batcat
alias cat "bat --plain"
alias less cat

# Replace man with command for colorfull man calls
function man
    /usr/bin/man $argv | bat --plain --language=man
end

# Replace fish help with command for colorfull help calls
function help
    $argv --help 2>&1 | bat --plain --language=help
end

# Add navcoin alias
alias nav navcoin-cli

# Replace default ls command with exa
alias ls "exa --group-directories-first"

# Replace tree command with exa
alias tree "exa --tree"

# Some more ls
alias l "ls -lF"
alias la "ls -aF"
alias ll "ls -alF"

# I want v to open vi and vi to open vim
alias v nvim
alias vi nvim
alias vim nvim
alias vd "nvim -d"
alias vimdiff "nvim -d"

# g to git (saves a few key strokes)
alias g git
alias ga "git add"
alias gc "git commit"
alias gg "git status"

# TokyoNight Color Palette
set -l foreground c0caf5
set -l selection 283457
set -l comment 565f89
set -l red f7768e
set -l orange ff9e64
set -l yellow e0af68
set -l green 9ece6a
set -l purple 9d7cd8
set -l cyan 7dcfff
set -l pink bb9af7

# Syntax Highlighting Colors
set -g fish_color_normal $foreground
set -g fish_color_command $cyan
set -g fish_color_keyword $pink
set -g fish_color_quote $yellow
set -g fish_color_redirection $foreground
set -g fish_color_end $orange
set -g fish_color_error $red
set -g fish_color_param $purple
set -g fish_color_comment $comment
set -g fish_color_selection --background=$selection
set -g fish_color_search_match --background=$selection
set -g fish_color_operator $green
set -g fish_color_escape $pink
set -g fish_color_autosuggestion $comment

# Completion Pager Colors
set -g fish_pager_color_progress $comment
set -g fish_pager_color_prefix $cyan
set -g fish_pager_color_completion $foreground
set -g fish_pager_color_description $comment
set -g fish_pager_color_selected_background --background=$selection

# Load fzf
type -q fzf_key_bindings && fzf_key_bindings

# Turn on vi mode for fish
fish_vi_key_bindings

# Lets bind fzf for our / and ? search
function fish_user_key_bindings
    bind -M default / fzf-history-widget
    bind -M default \? fzf-file-widget
end

# Load zoxide
zoxide init fish | source

# Load starship prompt
starship init fish | source
