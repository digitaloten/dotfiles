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
    neofetch \
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
    neofetch \
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

### Ubuntu 24.04
```sh
curl -sS https://starship.rs/install.sh | sh
curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
sudo add-apt-repository ppa:neovim-ppa/unstable
```

```sh
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
sudo install lazygit /usr/local/bin
```

```sh
sudo apt install \
    alacritty \
    bat \
    btop \
    eza \
    fish \
    fzf \
    git \
    golang \
    neofetch \
    neovim \
    nodejs \
    npm \
    ripgrep \
    rustup \
    stow \
    tmux \
    zoxide
```

```sh
rustup install stable
```

## Installation
```sh
curl -sS https://raw.githubusercontent.com/mxaddict/dotfiles/master/bin/.install | bash
```

## Hyprland...

### QT support
```sh
paru -Syu qt5-wayland qt6-wayland qt5ct qt6ct
```

### Video Codecs
```sh
paru -Syu gst-libav gst-plugins-{base,good,bad,ugly}
```

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

### Screenshots and Screenrecording
```sh
paru -Syu grimblast-git kooha
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
