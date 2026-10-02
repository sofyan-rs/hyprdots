pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import "../core"

Singleton {
    id: root
    property bool automatic: false
    property var automaticScreen: null

    function pin() {
        automatic = false
        dismissTimer.stop()
    }
    function toggle(screen) {
        pin()
        PopupManager.toggle("volume", screen)
    }
    function show() {
        // A manually opened volume panel stays open while using media keys.
        if (PopupManager.activeId === "volume" && !automatic) return
        const monitor = Hyprland.focusedMonitor
        const screen = Quickshell.screens.find(s => monitor && s.name === monitor.name) || Quickshell.screens[0]
        if (!screen) return
        automaticScreen = screen
        automatic = true
        PopupManager.activeScreen = screen
        PopupManager.activeId = "volume"
        dismissTimer.restart()
    }
    IpcHandler {
        target: "volume"
        function display(): void { root.show() }
        function status(): string { return JSON.stringify({open: PopupManager.activeId === "volume", automatic: root.automatic}) }
    }
    Timer {
        id: dismissTimer
        interval: 2500
        onTriggered: {
            if (root.automatic && PopupManager.activeId === "volume" && PopupManager.activeScreen === root.automaticScreen)
                PopupManager.close()
            root.automatic = false
        }
    }
}
