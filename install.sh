#!/usr/bin/env bash

set -e

# ==========================================
# 0. Set working directory
# ==========================================
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

echo "Running dotfiles installation from: $DOTFILES_DIR"

# ==========================================
# Variables & Packages
# ==========================================
# These packages will be installed via yay (handles both official and AUR packages)
PACKAGES=(    
    # Terminal & Core CLI Utilities
    "kitty" "zsh" "starship" "fastfetch" "zoxide" "eza" "bat" "fzf" "fd" "jq" 
    "stow" "tree" "wget" "unzip" "zip" "git" "zram-generator" "sassc" "btop" "inotify-tools" 
    "inkscape" "hyprland-autoname-workspaces" "xdg-utils" "nodejs" "npm" "bun" "ripgrep" "p7zip"

    # Audio & Bluetooth Stack
    "pipewire" "wireplumber" "pipewire-pulse" "pipewire-jack" 
    "pavucontrol" "bluez" "bluez-utils" "blueman" "cava"  "mpc" "mpd"
    
    # Network & VPN
    "networkmanager" "network-manager-applet" "networkmanager-pptp" "pptpclient" "networkmanager-openvpn" "networkmanager-wireguard" "wireguard-tools"
    
    # Desktop Environment & Theming
    "waybar" "quickshell" "rofi" "dunst" "nwg-look" "awww" "hyprpolkitagent" "papirus-icon-theme" "papirus-folders" "hyprcursor" "qt6ct"
    "apple_cursor" "kvantum"
    # Input Method (Mandarin)
    "fcitx5" "fcitx5-chinese-addons" "fcitx5-configtool" "fcitx5-gtk" "fcitx5-qt"
    
    # Screenshot, Media & Clipboard Tools
    "grim" "slurp" "wl-clipboard" "swappy" "chafa" "imagemagick"
    
    # Applications
    "visual-studio-code-bin" "google-chrome" "spotify-launcher" "discord" "vlc" 
    "nautilus" "localsend" "vlc-plugin-ffmpeg" "vlc-plugin-x264" "obs-studio" "luajit" "claude-desktop-bin"
    
    # Fonts
    "adobe-source-han-sans-cn-fonts" "noto-fonts" "noto-fonts-cjk"  "noto-fonts-emoji"
    "ttf-jetbrains-mono" "ttf-jetbrains-mono-nerd" "ttf-rubik-vf" "ttf-nerd-fonts-symbols"
    "ttf-nerd-fonts-symbols-mono" "woff2-font-awesome"
)

# System-wide services to enable (requires sudo)
SYSTEM_SERVICES=(
    "NetworkManager"
    "bluetooth"
)

# User-level services to enable (no sudo required)
USER_SERVICES=(
    "pipewire"
    "pipewire-pulse"
    "wireplumber"
    #"hyprland-autoname-workspaces"
)

# ==========================================
# 1. Install AUR Helper (yay)
# ==========================================
if ! command -v yay &> /dev/null; then
    echo "AUR helper 'yay' not found. Installing yay..."
    sudo pacman -Syu --needed base-devel git
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    cd /tmp/yay
    makepkg -si --noconfirm
    cd "$DOTFILES_DIR"
    rm -rf /tmp/yay
else
    echo "'yay' is already installed."
fi

# ==========================================
# 2. Install All Packages
# ==========================================
echo "Installing packages..."
yay -Syu --needed --noconfirm "${PACKAGES[@]}"

# ==========================================
# 3. Stow Folders
# ==========================================
echo "Stowing dotfiles..."

for dir in */; do
    dir_name="${dir%/}"
    
    if [[ "$dir_name" != .* ]]; then
        echo " -> Stowing $dir_name"
        stow -R -t "$HOME" "$dir_name"
    else
        echo " -> Skipping $dir_name (starts with a dot)"
    fi
done

# ==========================================
# 3.5. Install Hyprland Plugins
# ==========================================
echo "Setting up Hyprland plugins via hyprpm..."

hyprpm update
hyprpm add https://codeberg.org/zacoons/imgborders
#hyprpm enable imgborders


# ==========================================
# 4. Enable Services
# ==========================================
echo "Enabling system-wide services..."
for service in "${SYSTEM_SERVICES[@]}"; do
    sudo systemctl enable --now "$service"
done

echo "Enabling user-level services..."
for user_service in "${USER_SERVICES[@]}"; do
    systemctl --user enable --now "$user_service"
done

# ==========================================
# 5. Final Setup Steps
# ==========================================
echo "Updating font cache..."
fc-cache -fv

echo "Done! System setup complete."

# ==========================================
# 6. Install MacTahoe Icon Theme
# ==========================================

mkdir -p /tmp/MacTahoe-gtk-theme

echo "Downloading and installing MacTahoe icon theme..."
git clone https://github.com/vinceliuice/MacTahoe-gtk-theme.git /tmp/MacTahoe-gtk-theme
cd /tmp/MacTahoe-gtk-theme
./install.sh
cd "$DOTFILES_DIR"
rm -rf /tmp/MacTahoe-gtk-theme
echo "MacTahoe icon theme installed and temporary folder removed."

# Need to go to mimes and check if everything is well symlinked
echo "Go to share/icons/MacTahoe-dark/mimes and if folder svg is black then we need to run this:"
echo "rm 16 22 scalable"
echo "cp -r ~/.local/share/icons/MacTahoe/mimes/16 ~/.local/share/icons/MacTahoe/mimes/22 ~/.local/share/icons/MacTahoe/mimes/scalable ."
echo "gtk-update-icon-cache -f ~/.local/share/icons/MacTahoe-dark"

# ==========================================
# 7. Install Claude AI CLI
# ==========================================
echo "Installing Claude AI CLI..."
curl -fsSL https://claude.ai/install.sh | bash

# ==========================================
# 8. Install SF Pro Fonts from DMG
# ==========================================
echo "Setting up SF Pro Fonts..."
TEMP_FNT_DIR=$(mktemp -d)
cd "$TEMP_FNT_DIR"

if [ -f "$HOME/Downloads/SF-Pro.dmg" ]; then
    echo "Found SF-Pro.dmg in Downloads. Copying..."
    cp "$HOME/Downloads/SF-Pro.dmg" .
else
    echo "SF-Pro.dmg not found. Downloading from Apple..."
    wget -q --show-progress "https://devimages-cdn.apple.com/design/resources/download/SF-Pro.dmg"
fi

echo "Extracting DMG and Package chain..."
# Unpack DMG
7z x SF-Pro.dmg > /dev/null 2>&1
cd SFProFonts

# Unpack PKG
7z x "SF Pro Fonts.pkg" > /dev/null 2>&1

# Unpack Payload to get the actual font files
cd SFProFonts.pkg
bsdtar -xf Payload

echo "Installing fonts to ~/.local/share/fonts/SF-Pro..."
mkdir -p ~/.local/share/fonts/SF-Pro
mv Library/Fonts/* ~/.local/share/fonts/SF-Pro/

# Rebuild font cache just for the new additions
fc-cache -f

cd "$DOTFILES_DIR"
rm -rf "$TEMP_FNT_DIR"
echo "SF Pro fonts installed successfully."

echo "Done! System setup complete."