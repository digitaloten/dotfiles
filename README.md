# dotfiles

This is yet another reboot to my dotfiles config.

I've decided to switch to using `lua` for my `nvim` config as well as using `fish` for my default `shell` and `starship` for my shell prompt.

## Tools
1. `bat` for `cat` replacement
1. `exa` for `ls`
1. `fish` for my `shell`
1. `fzf` for fuzzy finder in cli for `history` and files
1. `git` for `git` duh...
1. `lua` for my `neovim` configs
1. `neovim` for my `$EDITOR`
1. `ripgrep` for a better `grep` alternative
1. `starship` for my prompt
1. `tmux` for my terminal multiplexer
1. `xclip` for clipboard support in `neovim`
1. `zoxide` for navigation (alternative to `cd` command)

## Installation
```sh
# Install the requirements
sudo apt install bat curl exa fish fzf git neovim ripgrep tmux xclip zoxide -y

# Install requirements for c/cpp development
sudo apt install clang clangd -y

# Install starship prompt
curl -sS https://starship.rs/install.sh | sh

# Run the actual installer dotfiles
curl -sS https://raw.githubusercontent.com/mxaddict/dotfiles/master/install | sh
```
