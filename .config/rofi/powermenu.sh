#!/usr/bin/env bash

# List of options with emoji or icons
options=(
  "  Lock"
  "  Suspend"
  "  Logout"
  "  Shutdown"
  "  Reboot"
)

# Turn array into newline-separated string
choice=$(printf "%s\n" "${options[@]}" | rofi -dmenu -theme ~/.config/rofi/themes/powermenu-grid.rasi -p "Power Menu")

case "$choice" in
  "  Lock") swaylock ;;
  "  Suspend") systemctl suspend ;;
  "  Logout") hyprctl dispatch exit ;;
  "  Shutdown") systemctl poweroff ;;
  "  Reboot") systemctl reboot ;;
esac
