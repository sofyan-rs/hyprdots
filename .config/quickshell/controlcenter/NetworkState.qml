import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root
    property bool active: false
    property var state: ({ enabled: false, wired: false, networks: [], saved: [], current: null })
    property string error: ""
    property string pendingAction: ""
    readonly property bool busy: actionProc.running
    readonly property bool scanning: busy && pendingAction === "scan"
    signal actionFinished(bool success, string action)

    function refresh() {
        if (!readProc.running && !busy)
            readProc.running = true
    }
    function run(request) {
        if (busy) return
        error = ""
        pendingAction = request.action
        actionProc.payload = JSON.stringify(request)
        actionProc.running = true
    }
    onActiveChanged: { if (active) refresh() }
    Component.onCompleted: refresh()

    Timer { interval: root.active ? 5000 : 15000; running: true; repeat: true; onTriggered: root.refresh() }

    Process {
        id: readProc
        command: ["python3", Quickshell.shellPath("controlcenter/network.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text)
                    if (result.ok) root.state = result.state
                    else root.error = result.error
                } catch (e) { root.error = "Could not read NetworkManager status" }
            }
        }
    }

    Process {
        id: actionProc
        property string payload: ""
        property bool succeeded: false
        command: ["python3", Quickshell.shellPath("controlcenter/network.py"), "action"]
        stdinEnabled: true
        onStarted: {
            succeeded = false
            write(payload + "\n")
            payload = ""
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text)
                    actionProc.succeeded = result.ok
                    if (!result.ok) root.error = result.error
                } catch (e) { root.error = "NetworkManager request failed" }
            }
        }
        onExited: {
            const action = root.pendingAction
            root.pendingAction = ""
            root.actionFinished(succeeded, action)
            Qt.callLater(root.refresh)
        }
    }
}
