import Quickshell
import Quickshell.Io
import QtQuick

// Qt only reads the icon theme at startup, so restart the shell when it
// changes (e.g. from nwg-look). Same restart as the SUPER+R keybind.
Scope {
    Process {
        running: true
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "icon-theme"]
        stdout: SplitParser {
            onRead: restartTimer.restart()
        }
    }

    // nwg-look can write the setting more than once; restart only after it settles.
    Timer {
        id: restartTimer
        interval: 600
        onTriggered: Quickshell.execDetached(["sh", "-c",
            "quickshell kill -p \"$HOME/.config/quickshell\"; sleep 0.3; env QT_QPA_PLATFORMTHEME=gtk3 quickshell -d"])
    }
}
