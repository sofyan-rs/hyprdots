pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    readonly property bool active: picker.running

    function pick() {
        if (picker.running) return
        PopupManager.close()
        picker.running = true
    }

    Process {
        id: picker
        command: ["hyprpicker", "--autocopy", "--format=hex"]
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("Color picker: " + text.trim())
        }
    }
}
