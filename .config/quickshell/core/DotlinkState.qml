pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Dotlink (phone link app) through its control socket; see dotlink/bridge.py.
Singleton {
    id: root

    // Dotlink's full state, or null while it isn't running.
    property var status: null
    readonly property bool running: status !== null
    readonly property var devices: status ? status.devices : []
    readonly property var onlineDevices: devices.filter(d => d.online)
    readonly property var onlinePhones: onlineDevices.filter(d => d.kind === "phone")
    // The phone the bar shows: the first online one with a battery reading.
    readonly property var mainDevice: onlinePhones.find(d => d.battery) || onlinePhones[0] || onlineDevices[0] || null
    readonly property var incoming: status ? status.incoming : []
    readonly property string cameraFrom: status && status.camera ? status.camera : ""
    readonly property string micFrom: status && status.mic ? status.mic : ""
    readonly property var casts: status && status.casts ? status.casts : ({})

    // Newest first; kept up to date from transfer events between status refreshes.
    property var transfers: []
    readonly property var activeTransfers: transfers.filter(t => t.state.state === "active")
    // The transfer the notch shows: the one that changed last.
    property var lastTransfer: null
    signal transferActivity()

    // Last request result, shown in the control center page.
    property string message: ""
    property bool messageIsError: false
    Timer { id: messageTimer; interval: 5000; onTriggered: root.message = "" }

    property int seq: 0
    property var callbacks: ({})

    Process {
        id: bridge
        command: ["python3", Quickshell.shellPath("dotlink/bridge.py")]
        running: true
        stdinEnabled: true
        // Restart it if it ever dies.
        onRunningChanged: if (!running) restartTimer.restart()
        stdout: SplitParser {
            onRead: line => {
                let msg
                try { msg = JSON.parse(line) } catch (e) { return }
                if (msg.t === "status") {
                    root.status = msg.status
                    root.transfers = msg.status ? msg.status.transfers.slice().sort((a, b) => b.started_at - a.started_at) : []
                } else if (msg.t === "transfer") {
                    root.updateTransfer(msg.transfer)
                } else if (msg.t === "reply") {
                    const cb = root.callbacks[msg.seq]
                    delete root.callbacks[msg.seq]
                    if (cb) cb(msg.reply)
                }
            }
        }
    }
    Timer { id: restartTimer; interval: 3000; onTriggered: bridge.running = true }

    function updateTransfer(t) {
        const list = root.transfers.slice()
        const i = list.findIndex(x => x.id === t.id)
        const prev = i >= 0 ? list[i] : null
        if (i >= 0) list[i] = t
        else list.unshift(t)
        root.transfers = list
        root.lastTransfer = t
        // Progress ticks are frequent; peek on changes of state and every so often while active.
        if (!prev || prev.state.state !== t.state.state || t.state.state === "active")
            root.transferActivity()
    }

    function request(req, cb) {
        root.seq++
        if (cb) root.callbacks[root.seq] = cb
        bridge.write(JSON.stringify({ seq: root.seq, req: req }) + "\n")
    }

    // Shows the reply in the control center; errors also as a notification.
    function report(reply) {
        root.messageIsError = !!reply.error
        root.message = reply.error || reply.ok || ""
        messageTimer.restart()
        if (reply.error) {
            notifyProc.command = ["notify-send", "-a", "Dotlink", "-i", "dotlink", "Dotlink", reply.error]
            notifyProc.running = true
        }
    }
    Process { id: notifyProc }

    // `to`: a device id, or empty for every connected device.
    function sendFiles(paths, to) {
        const files = paths.map(p => String(p).replace(/^file:\/\//, "")).map(p => decodeURIComponent(p)).filter(p => p)
        if (files.length === 0) return
        const req = { cmd: "send", paths: files }
        if (to) req.to = to
        root.request(req, root.report)
    }
    property string pickTarget: ""
    function pickAndSend(to) {
        if (pickProc.running) return
        root.pickTarget = to || ""
        pickProc.running = true
    }
    Process {
        id: pickProc
        command: ["zenity", "--file-selection", "--multiple", "--separator=\n", "--title=Send with Dotlink"]
        stdout: StdioCollector {
            onStreamFinished: root.sendFiles(text.split("\n"), root.pickTarget)
        }
    }
    function sendClipboard(to) {
        const req = { cmd: "clip" }
        if (to) req.to = to
        root.request(req, root.report)
    }
    function setMedia(kind, on, to) {
        const req = { cmd: "media", kind: kind, on: on }
        if (to) req.to = to
        root.request(req, root.report)
    }
    function setCast(id, on) {
        root.request({ cmd: "cast", id: id, on: on }, root.report)
    }
    function answer(id, accept) {
        root.request({ cmd: "answer_incoming", id: id, accept: accept }, root.report)
    }
    function clearTransfers() {
        root.request({ cmd: "clear_transfers" })
    }
    // A second launch brings up the running app's window (or starts it).
    function openWindow() {
        openProc.running = true
    }
    Process { id: openProc; command: ["dotlink"] }

    function castState(id) {
        const c = root.casts[id]
        return c ? c.state : "idle"
    }

    function formatBytes(b) {
        const units = ["B", "KB", "MB", "GB", "TB"]
        let i = 0
        while (b >= 1024 && i < units.length - 1) { b /= 1024; i++ }
        return (i >= 2 ? b.toFixed(1) : Math.round(b)) + " " + units[i]
    }
    function progress(t) {
        return t && t.size ? Math.max(0, Math.min(1, t.done / t.size)) : 0
    }

    IpcHandler {
        target: "dotlink"
        function send(path: string): void { root.sendFiles([path], "") }
        function pick(): void { root.pickAndSend("") }
        function clip(): void { root.sendClipboard("") }
        function state(): string { return JSON.stringify({ running: root.running, online: root.onlineDevices.map(d => d.name), transfers: root.transfers.length, incoming: root.incoming.length }) }
    }
}
