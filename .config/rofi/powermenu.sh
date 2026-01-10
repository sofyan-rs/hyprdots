#!/usr/bin/env bash

# List of options
options=(
  "  Lock"
  "  Suspend"
  "  Logout"
  "  Shutdown"
  "  Reboot"
)

# Show the menu and get the user's choice
choice=$(printf "%s\n" "${options[@]}" | rofi -dmenu -theme ~/.config/rofi/themes/powermenu-theme.rasi -p "Power Menu")

case "$choice" in
  "  Lock") swaylock ;;
  "  Suspend") systemctl suspend ;;
  "  Logout") hyprctl dispatch exit ;;
  "  Shutdown") systemctl poweroff ;;
  "  Reboot") systemctl reboot ;;
esac
