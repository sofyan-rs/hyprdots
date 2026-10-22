import Quickshell
import Quickshell.Io
import QtQuick

QtObject {
    id: root
    required property string key
    required property string name
    property bool enabled: true
    property var session: null
    property var weekly: null
    property double updatedAt: 0
    property string error: ""
    readonly property bool busy: reader.running

    property bool force: false

    function refresh(manual) {
        if (!enabled || reader.running) return
        force = manual === true
        reader.running = true
    }
    onEnabledChanged: if (enabled && !updatedAt) refresh()

    property Process reader: Process {
        command: ["python3", Quickshell.shellPath("aiusage/usage.py"), root.key].concat(root.force ? ["--force"] : [])
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const result = JSON.parse(text)
                    if (result.ok) {
                        root.session = result.session
                        root.weekly = result.weekly
                        root.updatedAt = result.updatedAt
                        root.error = ""
                    } else {
                        root.error = result.error || root.name + " usage unavailable"
                        if (result.updatedAt && result.updatedAt > root.updatedAt) {
                            root.session = result.session
                            root.weekly = result.weekly
                            root.updatedAt = result.updatedAt
                        }
                    }
                } catch (e) { root.error = "Invalid " + root.name + " usage response" }
            }
        }
    }
}
