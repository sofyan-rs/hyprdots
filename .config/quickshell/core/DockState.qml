pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool open: true
    property var screen: Quickshell.screens[0] || null
    property bool positionsLocked: true
    property string position: "bottom"
    property bool settingsLoaded: false

    FileView {
        id: settings
        path: Quickshell.env("HOME") + "/.config/quickshell/dock/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.settingsLoaded = false
            try {
                const data = JSON.parse(text())
                root.position = ["left", "bottom", "right"].includes(data.position) ? data.position : "bottom"
                root.open = data.visible !== false
                root.positionsLocked = data.locked !== false
            } catch (e) { }
            root.settingsLoaded = true
        }
        onLoadFailed: root.settingsLoaded = true
    }
    function save() {
        if (settingsLoaded) settings.setText(JSON.stringify({ position: position, visible: open, locked: positionsLocked }))
    }
    onPositionChanged: save()
    onOpenChanged: save()
    onPositionsLockedChanged: save()
    function resetDefaults() {
        position = "bottom"
        open = true
        positionsLocked = true
    }

    function toggleLock() {
        root.positionsLocked = !root.positionsLocked
    }

    function toggle(s) {
        if (root.open && root.screen === s) {
            root.open = false
        } else {
            root.screen = s || Quickshell.screens[0]
            root.open = true
        }
    }

    function close() {
        root.open = false
    }
}
