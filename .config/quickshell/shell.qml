//@ pragma UseQApplication
import Quickshell
import QtQuick
import "bar"
import "notifications"
import "launcher"
import "wallpaper"
import "dock"
import "clock"
import "keybinds"

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    Variants {
        model: Quickshell.screens
        DesktopClock {}
    }

    Variants {
        model: Quickshell.screens
        DesktopMenu { wallpaperPicker: wallpaperController }
    }

    NotificationToasts {
        screen: Quickshell.screens[0]
    }

    AppLauncher {}

    KeybindsPopup {}

    WallpaperPicker { id: wallpaperController }

    Dock {}
}
