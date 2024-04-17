# .files

## Tools
1. `bat` for `cat` replacement
1. `eza` for `ls`
1. `fish` for my `shell`
1. `fzf` for fuzzy finder in cli for `history` and files
1. `git` for `git` duh...
1. `neovim` for my `$EDITOR`
1. `ripgrep` for a better `grep` alternative
1. `starship` for my prompt
1. `tmux` for my terminal multiplexer
1. `zoxide` for navigation (alternative to `cd` command)

## Requirements
```sh
# Arch
paru -S \
    alacritty \
    bat \
    eza \
    fish \
    fzf \
    git \
    lazygit \
    neovim \
    ripgrep \
    starship \
    stow \
    tmux \
    zoxide

# Mac
brew install \
    alacritty \
    bat \
    eza \
    fish \
    fzf \
    git \
    lazygit \
    neovim \
    ripgrep \
    starship \
    stow \
    tmux \
    zoxide

# Ubuntu 22.04
curl -sS https://starship.rs/install.sh | sh
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
sudo add-apt-repository ppa:neovim-ppa/unstable
sudo add-apt-repository ppa:fish-shell/release-3
sudo apt install \
    bat \
    exa \
    fish \
    fzf \
    git \
    lazygit \
    neovim \
    ripgrep \
    stow \
    tmux \
    zoxide
```

## Installation
```sh
curl -sS https://raw.githubusercontent.com/mxaddict/dotfiles/master/bin/.install | bash
```

## Fonts
```sh
paru -Syu \
    ttf-hack \
    ttf-hack-nerd \
    ttf-noto-emoji-monochrome \
    ttf-noto-nerd \
    ttf-roboto \
    ttf-roboto-mono \
    ttf-roboto-mono-nerd
```
