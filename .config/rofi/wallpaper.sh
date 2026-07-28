#!/usr/bin/env bash

# Wallpaper picker for rofi, backed by waypaper.

THEME="$HOME/.config/rofi/themes/wallpaper-theme.rasi"
WAYPAPER_CONFIG="$HOME/.config/waypaper/config.ini"

folder=$(grep -m1 '^folder' "$WAYPAPER_CONFIG" 2>/dev/null | cut -d'=' -f2- | xargs)
folder="${folder/#\~/$HOME}"
folder="${folder:-$HOME/Pictures/Wallpapers}"

list_wallpapers() {
  find "$folder" -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.bmp' \) \
    -print0 | sort -z |
  while IFS= read -r -d '' file; do
    printf '%s\0icon\x1f%s\n' "$(basename "$file")" "$file"
  done
}

choice=$(list_wallpapers | rofi -dmenu -show-icons -theme "$THEME" -p " Wallpaper")

[[ -z "$choice" ]] && exit 0

selected=$(find "$folder" -maxdepth 1 -type f -iname "$choice" | head -n1)

[[ -z "$selected" ]] && exit 0

waypaper --wallpaper "$selected"
