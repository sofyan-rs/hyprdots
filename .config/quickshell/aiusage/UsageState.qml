pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../core"

Singleton {
    id: root
    property var session: null
    property var weekly: null
    property double updatedAt: 0
    property string error: ""
    readonly property bool busy: reader.running
    property double now: Date.now() / 1000

    function refresh() {
        if (!reader.running) reader.running = true
    }
    function remaining(window) {
        return window ? Math.round(100 - window.usedPercent) + "%" : "—"
    }
    function countdown(window) {
        if (!window || !window.resetsAt) return "Reset time unavailable"
        const minutes = Math.ceil((window.resetsAt - now) / 60)
        if (minutes <= 0) return "Waiting for quota update"
        const days = Math.floor(minutes / 1440)
        const hours = Math.floor((minutes % 1440) / 60)
        const mins = minutes % 60
        return "Resets in " + (days ? days + "d " : "") + (hours ? hours + "h " : "") + mins + "m"
    }
    Component.onCompleted: refresh()
    Timer { interval: 300000; running: true; repeat: true; onTriggered: root.refresh() }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.now = Date.now() / 1000 }
    Process {
        id: reader
        command: ["python3", Quickshell.shellPath("aiusage/usage.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text)
                    if (result.ok) {
                        root.session = result.session
                        root.weekly = result.weekly
                        root.updatedAt = result.updatedAt
                        root.error = ""
                    } else root.error = result.error || "Codex usage unavailable"
                } catch (e) { root.error = "Invalid Codex usage response" }
            }
        }
    }
    IpcHandler {
        target: "aiusage"
        function refresh(): void { root.refresh() }
        function status(): string {
            return JSON.stringify({ session: root.session, weekly: root.weekly,
                                   updatedAt: root.updatedAt, error: root.error, busy: root.busy })
        }
        function toggle(): void { PopupManager.toggle("aiusage", Quickshell.screens[0]) }
    }
}
