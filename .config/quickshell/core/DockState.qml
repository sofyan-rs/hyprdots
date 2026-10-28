pragma Singleton
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool open: true
    property var screen: Quickshell.screens[0] || null
    property bool positionsLocked: true
    property string position: "bottom"
    readonly property int minIconSize: 32
    readonly property int maxIconSize: 64
    property int iconSize: 44
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
                root.iconSize = typeof data.iconSize === "number" ? Math.max(root.minIconSize, Math.min(root.maxIconSize, Math.round(data.iconSize))) : 44
            } catch (e) { }
            root.settingsLoaded = true
        }
        onLoadFailed: root.settingsLoaded = true
    }
    // Pinned apps and their order, shared by the dock and the app launcher.
    property var pinnedIds: []
    property var orderKeys: []
    property bool pinsLoaded: false

    FileView {
        id: pinnedFile
        path: Quickshell.env("HOME") + "/.cache/quickshell/dock-pinned.json"
        onLoaded: {
            root.pinsLoaded = false
            try {
                const parsed = JSON.parse(text())
                // Older versions stored just the list of pinned app IDs.
                if (Array.isArray(parsed)) {
                    root.pinnedIds = parsed
                } else if (parsed && typeof parsed === "object") {
                    root.pinnedIds = Array.isArray(parsed.pinnedIds) ? parsed.pinnedIds.filter(id => typeof id === "string") : []
                    root.orderKeys = Array.isArray(parsed.orderKeys) ? [...new Set(parsed.orderKeys.filter(key => typeof key === "string"))] : []
                }
            } catch (e) {
                root.pinnedIds = []
            }
            root.pinsLoaded = true
        }
        onLoadFailed: {
            root.pinnedIds = []
            root.pinsLoaded = true
        }
    }

    function savePinned() {
        pinnedFile.setText(JSON.stringify({ pinnedIds: root.pinnedIds, orderKeys: root.orderKeys, locked: root.positionsLocked }))
    }

    function isPinned(id) {
        return !!id && root.pinnedIds.indexOf(id) >= 0
    }

    function togglePinned(id) {
        if (!id)
            return
        root.pinnedIds = root.isPinned(id) ? root.pinnedIds.filter(pid => pid !== id) : root.pinnedIds.concat([id])
        root.savePinned()
    }

    function save() {
        if (settingsLoaded) settings.setText(JSON.stringify({ position: position, visible: open, locked: positionsLocked, iconSize: iconSize }))
    }
    onPositionChanged: save()
    onOpenChanged: save()
    onPositionsLockedChanged: save()
    onIconSizeChanged: save()
    function resetDefaults() {
        position = "bottom"
        open = true
        positionsLocked = true
        iconSize = 44
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
