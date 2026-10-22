#!/usr/bin/env bash
set -euo pipefail

# Run from a terminal in the active Hyprland session, as your normal user.
if [[ $EUID -eq 0 ]]; then
    echo 'Jalankan sebagai pengguna biasa, bukan sudo bash.' >&2
    exit 1
fi
if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
    echo 'Jalankan dari terminal di sesi Hyprland.' >&2
    exit 1
fi

config_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_file="$config_dir/hyprland.lua"
module='require("config.scrolloverview")'
repo='https://github.com/yayuuu/hyprland-scroll-overview.git'

[[ -f "$config_file" && -f "$config_dir/config/scrolloverview.lua" ]]
existing_errors=$(hyprctl configerrors)
if [[ -n ${existing_errors//[[:space:]]/} ]]; then
    printf 'Perbaiki error konfigurasi yang sudah ada dahulu:\n%s\n' "$existing_errors" >&2
    exit 1
fi

# Fedora development headers also pull in Hyprland's matching dependencies.
sudo dnf install gcc-c++ cmake meson ninja-build git make pkgconf-pkg-config \
    hyprland-devel pixman-devel libdrm-devel pango-devel libinput-devel \
    systemd-devel wayland-devel libxkbcommon-devel lua-devel

# Build with the matching Fedora headers. This avoids hyprpm's failing header
# installation on this machine. Run again after upgrading Hyprland.
build_dir=$(mktemp -d /tmp/scrolloverview-build.XXXXXX)
trap 'rm -rf -- "$build_dir"' EXIT
git clone --depth 1 "$repo" "$build_dir/source"
make -C "$build_dir/source" all
plugin_file="$config_dir/plugins/scrolloverview.so"
mkdir -p -- "$config_dir/plugins"
install -m 755 "$build_dir/source/scrolloverview.so" "$plugin_file.new"
mv -f -- "$plugin_file.new" "$plugin_file"

if hyprctl -j plugin list | jq -e \
    'any(.[]; ((.name // "") | ascii_downcase) == "scrolloverview")' >/dev/null; then
    hyprctl plugin unload "$plugin_file"
fi
hyprctl plugin load "$plugin_file"

# Do not activate the configuration unless the plugin actually loaded.
if ! hyprctl -j plugin list | jq -e \
    'any(.[]; ((.name // "") | ascii_downcase) == "scrolloverview")' >/dev/null; then
    echo 'Plugin belum berhasil dimuat. Konfigurasi aktif tidak diubah.' >&2
    exit 1
fi

backup=$(mktemp "$config_file.before-scrolloverview.XXXXXX")
cp -p -- "$config_file" "$backup"
if ! grep -Fxq "$module" "$config_file"; then
    printf '\n%s\n' "$module" >> "$config_file"
fi
if ! hyprctl reload; then
    cp -p -- "$backup" "$config_file"
    hyprctl reload || true
    echo "Reload gagal; konfigurasi dipulihkan dari $backup" >&2
    exit 1
fi
errors=$(hyprctl configerrors)
if [[ -n ${errors//[[:space:]]/} ]]; then
    cp -p -- "$backup" "$config_file"
    hyprctl reload || true
    printf 'Konfigurasi dipulihkan karena error:\n%s\n' "$errors" >&2
    exit 1
fi

printf '\nScrollOverview aktif. Tekan Super+Tab untuk membuka/menutup overview.\nBackup: %s\n' "$backup"
