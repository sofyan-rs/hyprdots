//@ pragma UseQApplication
import Quickshell
import QtQuick
import "bar"
import "notifications"
import "launcher"
import "wallpaper"

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    NotificationToasts {
        screen: Quickshell.screens[0]
    }

    AppLauncher {}

    WallpaperPicker {}
}
