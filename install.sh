#!/usr/bin/env bash
set -e

# ===============================
# NON-ROOT CHECK
# ===============================
if [[ "$EUID" -eq 0 ]]; then
  echo "❌ Do NOT run this script as root."
  echo "➡️ Run it as a normal user. sudo will be requested when needed."
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "❌ sudo is not installed."
  exit 1
fi

# ===============================
# FEDORA CHECK
# ===============================
if [[ ! -f /etc/os-release ]]; then
  echo "❌ Unable to detect operating system."
  exit 1
fi

. /etc/os-release

if [[ "$ID" != "fedora" ]]; then
  echo "❌ This script is intended for Fedora only."
  exit 1
fi

FEDORA_VERSION="${VERSION_ID%%.*}"

if (( FEDORA_VERSION < 39 )); then
  echo "❌ Fedora $FEDORA_VERSION is not supported (minimum Fedora 39)."
  exit 1
fi

echo "✅ Fedora $VERSION_ID detected"

# ===============================
# REQUEST SUDO
# ===============================
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# ===============================
# HELPERS
# ===============================
is_installed() {
  rpm -q "$1" &>/dev/null
}

install_packages() {
  local to_install=()

  for pkg in "$@"; do
    if is_installed "$pkg"; then
      echo "✔ $pkg already installed — skipping"
    else
      to_install+=("$pkg")
    fi
  done

  if (( ${#to_install[@]} > 0 )); then
    sudo dnf install -y "${to_install[@]}"
  fi
}

# ===============================
# BASE PACKAGES
# ===============================
echo "📦 Installing required packages..."

install_packages \
  hyprland \
  rofi \
  waybar \
  power-profiles-daemon \
  grim \
  slurp \
  wl-clipboard \
  hyprpicker \
  mako \
  python3-pydbus \
  NetworkManager \
  network-manager-applet \
  bluez \
  bluez-tools \
  blueman \
  nwg-look \
  adw-gtk3-theme \
  waypaper \
  papirus-icon-theme \
  dnf-plugins-core

# ===============================
# HYPRLOCK (COPR)
# ===============================
if ! is_installed hyprlock; then
  echo "🧩 Enabling COPR repository for hyprlock..."
  sudo dnf copr enable -y solopasha/hyprland
  sudo dnf install -y hyprlock
else
  echo "✔ hyprlock already installed — skipping"
fi

# ===============================
# AWWW (COPR)
# ===============================
if ! is_installed awww; then
  echo "🧩 Enabling COPR repository for awww..."
  sudo dnf copr enable -y alebastr/sway-extras
  sudo dnf install -y awww
else
  echo "✔ awww already installed — skipping"
fi

# ===============================
# FLATPAK GTK THEME
# ===============================
echo "🎨 Applying Flatpak GTK theme overrides..."
sudo flatpak override --filesystem=xdg-data/themes
sudo flatpak mask org.gtk.Gtk3theme.adw-gtk3-dark || true

# ===============================
# COPY CONFIG FILES
# ===============================
echo "📁 Copying config files..."
mkdir -p ~/.config
cp -rn .config/* ~/.config/ || true

# ===============================
# FONTS
# ===============================
echo "🔤 Installing fonts..."
mkdir -p ~/.local/share/fonts
cp -rn .local/share/fonts/* ~/.local/share/fonts/ || true
fc-cache -fv

# ===============================
# CURSOR THEME
# ===============================
echo "🖱 Installing cursor theme..."
mkdir -p ~/.local/share/icons
cp -rn .local/share/icons/* ~/.local/share/icons/ || true

# ===============================
# WALLPAPERS
# ===============================
echo "🖼 Installing wallpapers..."
mkdir -p ~/Pictures/Wallpapers
cp -rn wallpapers/* ~/Pictures/Wallpapers/ || true

# ===============================
# WAYBAR MAKO SCRIPT
# ===============================
echo "🔔 Installing Waybar mako notification script..."
mkdir -p ~/.local/bin

if [[ ! -f ~/.local/bin/waybar-mako-notif.py ]]; then
  cp .local/bin/waybar-mako-notif.py ~/.local/bin/
  chmod +x ~/.local/bin/waybar-mako-notif.py
else
  echo "✔ waybar-mako-notif.py already exists — skipping"
fi

# ===============================
# PATH CHECK
# ===============================
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
  echo "➕ Adding ~/.local/bin to PATH"
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
fi

echo
echo "✅ Installation completed successfully!"
echo "➡️ Open waypaper once and pick 'awww' as the backend to set your wallpaper."
echo "➡️ Reboot or log out / log in is recommended."
echo "➡️ Enjoy this Hyprland setup!"