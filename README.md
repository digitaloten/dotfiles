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

### Arch
```sh
paru -Syu \
    alacritty \
    bat \
    btop \
    eza \
    fish \
    fzf \
    git \
    go \
    lazygit \
    neovim \
    nodejs \
    npm \
    ripgrep \
    rust \
    starship \
    stow \
    tmux \
    zoxide
```

### Mac
```sh
brew install \
    alacritty \
    bat \
    btop \
    eza \
    fish \
    fzf \
    git \
    go \
    lazygit \
    neovim \
    nodejs \
    npm \
    ripgrep \
    rust \
    starship \
    stow \
    tmux \
    zoxide
```

### Ubuntu 22.04
```sh
curl -sS https://starship.rs/install.sh | sh
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
sudo add-apt-repository ppa:neovim-ppa/unstable
sudo add-apt-repository ppa:fish-shell/release-3
sudo apt install \
    alacritty \
    bat \
    btop \
    exa \
    fish \
    fzf \
    git \
    go \
    lazygit \
    neovim \
    nodejs \
    npm \
    ripgrep \
    rust \
    stow \
    tmux \
    zoxide
```

## Installation
```sh
curl -sS https://raw.githubusercontent.com/mxaddict/dotfiles/master/bin/.install | bash
```

## Hyprland...

### NetworkManager (Network)
```sh
paru -Syu networkmanager network-manager-applet
sudo systemctl enable NetworkManager
sudo systemctl start NetworkManager
```

### Bluez (Bluetooth)
```sh
paru -Syu blueman bluez
sudo systemctl enable bluetooth
sudo systemctl start bluetooth
```

### Pipewire (Audio)
```sh
paru -Syu pipewire pipewire-alsa pipewire-pulse pavucontrol wireplumber
```

### Notifications / Wallpaper / Waybar / Lockscreen
```sh
paru -Syu hyprpaper waybar swaync swaylock
```

### Fonts
```sh
paru -Syu \
    ttf-hack \
    ttf-hack-nerd \
    ttf-noto-emoji-monochrome \
    ttf-noto-nerd \
    ttf-roboto \
    ttf-roboto-mono \
    ttf-roboto-mono-nerd \
    ttf-font-awesome
```

### Cursor
```sh
paru -Syu bibata-cursor-theme
```

### Icon Theme
```sh
git clone https://github.com/vinceliuice/Colloid-icon-theme.git colloid --depth=1
cd colloid
./install.sh
rm -rf lavanda
```

### Gtk Theme
```sh
paru -Syu gnome-themes-extra gtk-engine-murrine sassc qt6ct
git clone https://github.com/vinceliuice/Lavanda-gtk-theme.git lavanda --depth=1
cd lavanda
./install.sh
rm -rf lavanda
```
