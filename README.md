# dotfiles

This is yet another reboot to my dotfiles config.

I've decided to switch to using `lua` for my `nvim` config as well as using `fish` for my default `shell` and `starship` for my shell prompt.

## Tools
1. `exa` for `ls`
2. `neovim` for my `$EDITOR`
3. `lua` for my `neovim` configs
4. `fish` for my `shell`
5. `starship` for my prompt
6. `tmux` for my terminal multiplexer
7. `xclip` for clipboard support in `neovim`

## Installation
```sh
# Install the requirements
sudo apt install curl exa neovim xclip git tmux ripgrep -y

# Install requirements for c/cpp development
sudo apt install clang clangd -y

# Run this in a non root terminal
sh -c "$(curl -sL https://raw.githubusercontent.com/mxaddict/dotfiles/master/install)"
```
