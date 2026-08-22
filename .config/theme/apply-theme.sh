#!/usr/bin/env bash
# Applies a color palette (chosen by wallpaper) to kitty and quickshell.
#
# Called automatically by waypaper's post_command with the new wallpaper
# path ($wallpaper), so it fires no matter how the wallpaper was changed:
# quickshell's wallpaper picker, `waypaper --wallpaper`, `waypaper --random`,
# or the waypaper GUI.
#
# Usage: apply-theme.sh [/path/to/wallpaper]
#   With no argument, reads the current wallpaper from waypaper's config.ini.

set -uo pipefail

THEME_DIR="$HOME/.config/theme"
PALETTES_DIR="$THEME_DIR/palettes"
MAP_FILE="$THEME_DIR/wallpapers.conf"
STATE_FILE="$THEME_DIR/current-palette"
DEFAULT_PALETTE="sakura-ember"

WAYPAPER_CONFIG="$HOME/.config/waypaper/config.ini"

wallpaper="${1:-}"
if [[ -z "$wallpaper" ]]; then
  wallpaper=$(grep -m1 '^wallpaper' "$WAYPAPER_CONFIG" 2>/dev/null | cut -d'=' -f2- | xargs)
fi
wallpaper="${wallpaper/#\~/$HOME}"
base="$(basename -- "$wallpaper")"

palette_name="$DEFAULT_PALETTE"
if [[ -f "$MAP_FILE" ]]; then
  mapped=$(grep -m1 -E "^${base}=" "$MAP_FILE" 2>/dev/null | cut -d'=' -f2-)
  [[ -n "$mapped" ]] && palette_name="$mapped"
fi

palette_file="$PALETTES_DIR/${palette_name}.sh"
if [[ ! -f "$palette_file" ]]; then
  echo "apply-theme: unknown palette '$palette_name', falling back to '$DEFAULT_PALETTE'" >&2
  palette_name="$DEFAULT_PALETTE"
  palette_file="$PALETTES_DIR/${palette_name}.sh"
fi

# shellcheck source=/dev/null
source "$palette_file"

echo "$palette_name" > "$STATE_FILE"

# ---- Kitty ----
cat > "$HOME/.config/kitty/theme.conf" <<EOF
background            $BG
foreground             $FG
cursor                 $CURSOR
selection_background   $SELECTION_BG
selection_foreground   $SELECTION_FG

color0                 $COLOR0
color8                 $COLOR8

color1                 $COLOR1
color9                 $COLOR9

color2                 $COLOR2
color10                $COLOR10

color3                 $COLOR3
color11                $COLOR11

color4                 $COLOR4
color12                $COLOR12

color5                 $COLOR5
color13                $COLOR13

color6                 $COLOR6
color14                $COLOR14

color7                 $COLOR7
color15                $COLOR15
EOF

# ---- Quickshell ----
cat > "$THEME_DIR/quickshell-colors.css" <<EOF
@define-color bg $BG;
@define-color bg-alt $BG_ALT;
@define-color fg $FG;
@define-color fg-alt $FG_ALT;
@define-color accent $ACCENT;
@define-color secondary $SECONDARY;
@define-color border $BORDER;
@define-color on-accent $ON_ACCENT;
@define-color workspace-focused-bg $WORKSPACE_FOCUSED_BG;
@define-color clock-bg $CLOCK_BG;
@define-color wallpaper-icon $WALLPAPER_ICON;
@define-color shadow $SHADOW;
EOF

# ---- Hyprlock ----
hex_to_rgb() {
  local hex="${1#\#}"
  printf "%d, %d, %d" "0x${hex:0:2}" "0x${hex:2:2}" "0x${hex:4:2}"
}

cat > "$HOME/.config/hypr/hyprlock-colors.conf" <<EOF
\$wallpaper = $wallpaper
\$lock_outer = $(hex_to_rgb "$BORDER")
\$lock_inner = $(hex_to_rgb "$BG")
\$lock_font = $(hex_to_rgb "$FG")
\$lock_check = $(hex_to_rgb "$ACCENT")
\$lock_fail = $(hex_to_rgb "$SECONDARY")
\$lock_accent = $(hex_to_rgb "$ACCENT")
EOF

# ---- Reload running apps ----
pkill -SIGUSR1 kitty 2>/dev/null

echo "apply-theme: applied '$palette_name' for wallpaper '$base'"
