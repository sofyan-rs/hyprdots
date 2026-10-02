import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../core"

PanelWindow {
    id: root
    readonly property bool open: PopupManager.activeId === "wallpaper"
    property string folderPath: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property string currentPath: ""
    property string query: ""
    property int pageIndex: 0
    property var library: []
    readonly property var filtered: library.filter(item => item.name.toLowerCase().includes(query.toLowerCase()))
    readonly property int pageCount: Math.max(1, Math.ceil(filtered.length / 4))
    readonly property var pageImages: filtered.slice(pageIndex * 4, pageIndex * 4 + 4)
    readonly property bool busy: setProc.running
    property string error: ""
    onQueryChanged: pageIndex = 0
    onPageCountChanged: pageIndex = Math.min(pageIndex, pageCount - 1)
    screen: PopupManager.activeScreen
    visible: open
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins.top: Colors.barHeight + Colors.popupTopGap
    margins.right: 14
    implicitWidth: Math.min(470, screen ? screen.width - 28 : 470)
    implicitHeight: Math.min(content.implicitHeight, screen ? screen.height - 80 : 650)
    WlrLayershell.namespace: "quickshell-wallpaper"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    onOpenChanged: {
        if (open) { configFile.reload(); content.forceActiveFocus() }
    }
    IpcHandler {
        target: "wallpaper"
        function toggle(): void {
            let targetScreen = Quickshell.screens[0]
            for (const s of Quickshell.screens) {
                if (Hyprland.monitorFor(s) === Hyprland.focusedMonitor) { targetScreen = s; break }
            }
            PopupManager.toggle("wallpaper", targetScreen)
        }
    }
    function rebuildLibrary() { libraryTimer.restart() }
    Timer { id: libraryTimer; interval: 80; onTriggered: { libraryProc.running = false; libraryProc.command = ["python3", Quickshell.shellPath("wallpaper/library.py"), root.folderPath]; libraryProc.running = true } }
    Process {
        id: libraryProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.library = JSON.parse(text) }
                catch (e) { root.error = "Could not read wallpaper library" }
            }
        }
    }
    readonly property string currentPreview: {
        const item = library.find(item => item.path === currentPath)
        return item ? item.preview : ""
    }
    function setWallpaper(path) {
        if (busy || !path) return
        error = ""
        setProc.command = ["waypaper", "--wallpaper", path]
        setProc.running = true
    }
    function shuffle() {
        const choices = filtered.filter(item => item.path !== currentPath)
        if (choices.length) setWallpaper(choices[Math.floor(Math.random() * choices.length)].path)
    }
    function done() { PopupManager.close() }
    function back() { PopupManager.toggle("controlcenter", root.screen) }
    Process {
        id: setProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) configFile.reload()
            else root.error = "Could not apply wallpaper. Try again."
        }
    }
    FileView {
        id: configFile
        path: Quickshell.env("HOME") + "/.config/waypaper/config.ini"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            function expand(path) { return path.startsWith("~") ? Quickshell.env("HOME") + path.slice(1) : path }
            const folder = text().match(/^folder\s*=\s*(.+)$/m)
            const wallpaper = text().match(/^wallpaper\s*=\s*(.+)$/m)
            if (folder) root.folderPath = expand(folder[1].trim())
            if (wallpaper) root.currentPath = expand(wallpaper[1].trim())
        }
    }
    FolderListModel {
        id: folderModel
        folder: "file://" + root.folderPath
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
        showDirs: false
        sortField: FolderListModel.Name
        onCountChanged: root.rebuildLibrary()
        onStatusChanged: if (status === FolderListModel.Ready) root.rebuildLibrary()
    }
    PersonalizationContent { id: content; anchors.fill: parent; controller: root }
}
