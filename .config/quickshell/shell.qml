//@ pragma UseQApplication
import Quickshell
import QtQuick
import "bar"
import "notifications"
import "launcher"
import "wallpaper"
import "dock"
import "clock"

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    Variants {
        model: Quickshell.screens
        DesktopClock {}
    }

    NotificationToasts {
        screen: Quickshell.screens[0]
    }

    AppLauncher {}

    WallpaperPicker {}

    Dock {}
}
