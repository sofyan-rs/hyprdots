pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    readonly property bool active: inhibitor.running

    function toggle() {
        inhibitor.running = !inhibitor.running
    }

    Process {
        id: inhibitor
        command: ["systemd-inhibit", "--what=idle", "--mode=block",
                  "--who=Quickshell caffeine", "--why=Caffeine enabled", "cat"]
        stdinEnabled: true
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("Caffeine: " + text.trim())
        }
    }

    IpcHandler {
        target: "caffeine"
        function toggle(): void { root.toggle() }
        function status(): bool { return root.active }
    }
}
