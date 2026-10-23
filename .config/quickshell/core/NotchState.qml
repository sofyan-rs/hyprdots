pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import QtQuick

Singleton {
    id: root

    property bool enabled: true
    property string style: "notch"
    property bool expandOnHover: true
    property bool mediaPeek: true
    property bool volumeOsd: true
    // Show the current lyric line in the collapsed notch (toggled from the Media tab).
    property bool lyricsInNotch: false
    // Show romaji under Japanese lyrics (and in the collapsed notch).
    property bool lyricsRomaji: false
    property bool settingsLoaded: false

    // Short-lived activity shown in the collapsed notch: "", "media", "volume", "privacy", "caps", "color" or "caffeine".
    property string peekKind: ""
    signal expandToggleRequested()
    signal tabRequested(string tab)
    signal collapseRequested()

    // Shelf entries: a file path (string, a reference, not a copy), { text } or { url }.
    property var shelf: []
    property bool shelfLoaded: false

    // Privacy: apps using the microphone, camera or capturing the screen.
    property var cameraDeviceApps: []
    readonly property var privacy: {
        const mic = [], camera = root.cameraDeviceApps.slice(), screen = []
        const add = (list, app) => { if (app && !list.includes(app)) list.push(app) }
        for (const group of Pipewire.linkGroups.values) {
            if (!group || group.state !== PwLinkState.Active || !group.source || !group.target) continue
            const props = group.source.properties || {}
            const cls = props["media.class"] || ""
            const target = group.target.properties || {}
            const app = target["application.name"] || target["node.description"] || target["node.name"] || ""
            if (cls.startsWith("Audio/Source")) add(mic, app)
            else if (cls === "Video/Source" && ["v4l2", "libcamera"].includes(props["device.api"])) add(camera, app)
            else if (cls === "Video/Source" || cls === "Stream/Output/Video") add(screen, app)
        }
        return { mic: mic, camera: camera, screen: screen }
    }
    // Link groups and their nodes only report state and properties while bound.
    PwObjectTracker {
        objects: Pipewire.linkGroups.values.reduce((list, g) => list.concat([g, g.source, g.target]), [])
    }
    readonly property bool privacyActive: privacy.mic.length + privacy.camera.length + privacy.screen.length > 0
    property var lastPrivacy: ({ mic: [], camera: [], screen: [] })
    property string privacyPeekText: ""
    onPrivacyChanged: {
        const labels = { camera: "Camera", screen: "Screen sharing", mic: "Microphone" }
        for (const kind of ["camera", "screen", "mic"]) {
            const started = privacy[kind].filter(app => !lastPrivacy[kind].includes(app))
            if (started.length > 0) {
                privacyPeekText = labels[kind] + " in use  ·  " + started.join(", ")
                peek("privacy")
                break
            }
        }
        lastPrivacy = privacy
    }

    Process {
        command: ["python3", Quickshell.shellPath("notch/sysmon.py"), "camera"]
        running: root.enabled
        stdout: SplitParser {
            onRead: line => {
                try { root.cameraDeviceApps = JSON.parse(line) } catch (e) { }
            }
        }
    }

    // Caps Lock, read from the keyboard LEDs; toggling it peeks in the notch.
    property bool capsLock: false
    property bool capsLockKnown: false
    Process {
        command: ["python3", Quickshell.shellPath("notch/sysmon.py"), "capslock"]
        running: root.enabled
        stdout: SplitParser {
            onRead: line => {
                const on = line.trim() === "1"
                // The first reading is the startup state, not a key press.
                if (root.capsLockKnown && on !== root.capsLock) {
                    root.capsLock = on
                    root.peek("caps")
                } else {
                    root.capsLock = on
                }
                root.capsLockKnown = true
            }
        }
    }

    // Colour picker and caffeine report back through a peek.
    Connections {
        target: ColorPickerState
        function onPicked(color) { root.peek("color") }
    }
    Connections {
        target: CaffeineState
        function onActiveChanged() { root.peek("caffeine") }
    }

    // System stats stream only while a notch shows the system tab.
    property int systemViewers: 0
    property var system: null
    property var cpuHistory: []
    Process {
        command: ["python3", Quickshell.shellPath("notch/sysmon.py"), "stats"]
        running: root.systemViewers > 0
        stdout: SplitParser {
            onRead: line => {
                try {
                    const data = JSON.parse(line)
                    root.system = data
                    root.cpuHistory = root.cpuHistory.concat([data.cpu]).slice(-40)
                } catch (e) { }
            }
        }
    }

    // Same filter as the control center: skip idle players with nothing loaded.
    readonly property var players: Mpris.players.values.filter(p => p.trackTitle !== "" || p.playbackState !== MprisPlaybackState.Stopped)
    // Picked with the dots in the notch; cleared when another player starts.
    property var selectedPlayer: null
    // Last player that was playing, so pausing does not jump to another player.
    property var lastActivePlayer: null
    readonly property var player: players.includes(selectedPlayer) ? selectedPlayer
        : (players.find(p => p.isPlaying) || (players.includes(lastActivePlayer) ? lastActivePlayer : null) || players[0] || null)
    function selectPlayer(p) {
        if (players.includes(p)) selectedPlayer = p
    }
    Instantiator {
        model: root.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() {
                if (!modelData.isPlaying) return
                root.lastActivePlayer = modelData
                root.selectedPlayer = null
            }
        }
    }
    Component.onCompleted: lastActivePlayer = players.find(p => p.isPlaying) || null

    // Lyrics from lrclib.net (cached locally by notch/lyrics.py).
    // lyricsStatus: "", "loading", "synced", "plain", "instrumental", "missing" or "error".
    property string lyricsStatus: ""
    property var lyricsLines: []
    property string lyricsPlain: ""
    property bool lyricsHasRomaji: false
    property int lyricIndex: -1
    readonly property string currentLyric: lyricIndex >= 0 && lyricIndex < lyricsLines.length
        ? ((lyricsRomaji && lyricsLines[lyricIndex].romaji) || lyricsLines[lyricIndex].text) : ""
    readonly property string lyricsKey: player && player.trackTitle ? player.trackTitle + "\n" + (player.trackArtist || "") : ""
    onLyricsKeyChanged: {
        lyricsStatus = ""
        lyricsLines = []
        lyricsPlain = ""
        lyricsHasRomaji = false
        lyricIndex = -1
        if (lyricsKey) lyricsDelay.restart()
    }
    // Metadata often arrives in pieces; wait for it to settle.
    Timer {
        id: lyricsDelay
        interval: 600
        onTriggered: {
            if (!root.player || !root.lyricsKey) return
            lyricsProc.requestedKey = root.lyricsKey
            lyricsProc.running = false
            lyricsProc.command = ["python3", Quickshell.shellPath("notch/lyrics.py"),
                root.player.trackTitle, root.player.trackArtist || "", root.player.trackAlbum || "",
                String(root.player.lengthSupported ? Math.round(root.player.length) : 0)]
            root.lyricsStatus = "loading"
            lyricsProc.running = true
        }
    }
    Process {
        id: lyricsProc
        // A quick track change can finish an older lookup late; ignore results for other tracks.
        property string requestedKey: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (lyricsProc.requestedKey !== root.lyricsKey) return
                try {
                    const r = JSON.parse(text)
                    root.lyricsLines = r.lines || []
                    root.lyricsPlain = r.plain || ""
                    root.lyricsHasRomaji = r.hasRomaji === true
                    root.lyricsStatus = r.status
                    root.updateLyricIndex()
                } catch (e) { root.lyricsStatus = "error" }
            }
        }
    }
    function updateLyricIndex() {
        if (!player || lyricsLines.length === 0) { lyricIndex = -1; return }
        const t = player.position + 0.2  // small lead so lines do not feel late
        let i = -1
        for (let n = 0; n < lyricsLines.length && lyricsLines[n].t <= t; n++) i = n
        if (i !== lyricIndex) lyricIndex = i
    }
    // MPRIS does not push positions, so poll while synced lyrics are playing.
    Timer {
        running: root.enabled && root.lyricsStatus === "synced" && root.player !== null && root.player.isPlaying
        interval: 250; repeat: true
        onTriggered: {
            root.player.positionChanged()
            root.updateLyricIndex()
        }
    }

    FileView {
        id: settings
        path: Quickshell.env("HOME") + "/.config/quickshell/notch/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.settingsLoaded = false
            try {
                const data = JSON.parse(text())
                root.enabled = data.enabled !== false
                root.style = ["notch", "island"].includes(data.style) ? data.style : "notch"
                root.expandOnHover = data.expandOnHover !== false
                root.mediaPeek = data.mediaPeek !== false
                root.volumeOsd = data.volumeOsd !== false
                root.lyricsInNotch = data.lyricsInNotch === true
                root.lyricsRomaji = data.lyricsRomaji === true
            } catch (e) { }
            root.settingsLoaded = true
        }
        onLoadFailed: root.settingsLoaded = true
    }
    FileView {
        id: shelfFile
        path: Quickshell.env("HOME") + "/.config/quickshell/notch/shelf.json"
        onLoaded: {
            try {
                const data = JSON.parse(text())
                root.shelf = Array.isArray(data) ? data.filter(e => typeof e === "string"
                    || (e && (typeof e.text === "string" || typeof e.url === "string"))) : []
            } catch (e) { }
            root.shelfLoaded = true
        }
        onLoadFailed: root.shelfLoaded = true
    }
    // FileTransfer portal keys per shelf path, so Flatpak apps can read dropped files.
    property var transferKeys: ({})
    property var transferPending: []
    Process {
        id: transferProc
        command: ["python3", Quickshell.shellPath("notch/filetransfer.py")]
        running: root.shelf.some(e => typeof e === "string")
        stdinEnabled: true
        onStarted: {
            root.transferKeys = {}
            root.transferPending = []
            root.registerTransfers()
        }
        stdout: SplitParser {
            onRead: line => {
                try {
                    const r = JSON.parse(line)
                    if (r.key) {
                        const next = Object.assign({}, root.transferKeys)
                        next[r.path] = r.key
                        root.transferKeys = next
                    }
                } catch (e) { }
            }
        }
    }
    function registerTransfers() {
        if (!transferProc.running) return
        for (const path of shelf) {
            if (typeof path !== "string") continue
            if (transferKeys[path] || transferPending.includes(path)) continue
            transferPending = transferPending.concat([path])
            transferProc.write(path + "\n")
        }
    }
    onShelfChanged: registerTransfers()

    function saveShelf() {
        if (shelfLoaded) shelfFile.setText(JSON.stringify(shelf))
    }
    function sameEntry(a, b) {
        if (typeof a === "string" || typeof b === "string") return a === b
        return a.text === b.text && a.url === b.url
    }
    function addEntries(entries) {
        const next = shelf.slice()
        for (const e of entries) {
            if (!next.some(other => sameEntry(other, e))) next.push(e)
        }
        shelf = next
        saveShelf()
    }
    // Files become paths, web links become { url } entries.
    function addFiles(urls) {
        const entries = []
        for (const u of urls) {
            const url = u.toString().trim()
            if (url.startsWith("file://")) entries.push(decodeURIComponent(url.slice(7)))
            else if (/^https?:\/\//.test(url)) entries.push({ url: url })
        }
        addEntries(entries)
    }
    function addText(text) {
        const trimmed = (text || "").trim()
        if (!trimmed) return
        addEntries([/^https?:\/\/\S+$/.test(trimmed) ? { url: trimmed } : { text: text }])
    }
    function removeEntry(entry) {
        shelf = shelf.filter(e => !sameEntry(e, entry))
        saveShelf()
    }
    function clearShelf() {
        shelf = []
        saveShelf()
    }
    function pasteFiles() {
        if (!pasteProc.running) pasteProc.running = true
    }
    // Files when the clipboard has them, plain text otherwise. The first line says which.
    Process {
        id: pasteProc
        command: ["sh", "-c", "if wl-paste --list-types | grep -qx text/uri-list; then echo files; wl-paste --no-newline --type text/uri-list; else echo text; wl-paste --no-newline --type text/plain; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const newline = text.indexOf("\n")
                if (newline < 0) return
                const kind = text.slice(0, newline), body = text.slice(newline + 1)
                if (kind === "files") root.addFiles(body.split(/\r?\n/).filter(l => l && !l.startsWith("#")))
                else root.addText(body)
            }
        }
    }

    function save() {
        if (settingsLoaded) settings.setText(JSON.stringify({ enabled: enabled, style: style, expandOnHover: expandOnHover, mediaPeek: mediaPeek, volumeOsd: volumeOsd, lyricsInNotch: lyricsInNotch, lyricsRomaji: lyricsRomaji }))
    }
    onEnabledChanged: save()
    onStyleChanged: save()
    onExpandOnHoverChanged: save()
    onMediaPeekChanged: save()
    onVolumeOsdChanged: save()
    onLyricsInNotchChanged: save()
    onLyricsRomajiChanged: save()
    function resetDefaults() {
        enabled = true
        style = "notch"
        expandOnHover = true
        mediaPeek = true
        volumeOsd = true
    }

    function peek(kind) {
        if (!enabled || (kind === "media" && !player) || (kind === "privacy" && privacy.mic.length + privacy.camera.length + privacy.screen.length === 0)) return
        peekKind = kind
        peekTimer.restart()
    }

    Timer {
        id: peekTimer
        interval: 2200
        onTriggered: root.peekKind = ""
    }

    Connections {
        target: root.player
        function onTrackTitleChanged() {
            if (root.mediaPeek && root.player && root.player.trackTitle) root.peek("media")
        }
    }

    IpcHandler {
        target: "notch"
        function toggle(): void { root.enabled = !root.enabled }
        function peekMedia(): void { root.peek("media") }
        function peekKind(kind: string): void { root.peek(kind) }
        function lyricsReload(): void { if (root.lyricsKey) lyricsDelay.restart() }
        function lyricsStatus(): string { return JSON.stringify({ key: root.lyricsKey, status: root.lyricsStatus, lines: root.lyricsLines.length, index: root.lyricIndex }) }
        function toggleExpand(): void { root.expandToggleRequested() }
        function collapse(): void { root.collapseRequested() }
        function openShelf(): void { root.tabRequested("shelf") }
        function openTab(tab: string): void { root.tabRequested(tab) }
        function privacyStatus(): string {
            return JSON.stringify({
                privacy: root.privacy,
                links: Pipewire.linkGroups.values.map(g => ({
                    state: g.state,
                    source: g.source ? (g.source.properties || {})["media.class"] : null,
                    sourceName: g.source ? g.source.name : null,
                    sourceType: g.source ? g.source.type : null,
                    target: g.target ? (g.target.properties || {})["application.name"] || g.target.name : null
                }))
            })
        }
        function shelfAdd(path: string): void { root.addFiles(["file://" + path]) }
        function shelfAddText(text: string): void { root.addText(text) }
        function shelfPaste(): void { root.pasteFiles() }
        function shelfClear(): void { root.clearShelf() }
        function shelfStatus(): string { return JSON.stringify({ shelf: root.shelf, transferKeys: root.transferKeys }) }
    }
}
