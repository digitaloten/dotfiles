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
sudo apt install bat curl entr exa fzf git neovim ripgrep tmux xclip zoxide -y

# Install requirements for c/cpp development
sudo apt install clang clangd -y

# Install starship prompt
curl -sS https://starship.rs/install.sh | sh

# Run the actual installer dotfiles
curl -sS https://raw.github.com/mxaddict/dotfiles/master/install | sh
```
