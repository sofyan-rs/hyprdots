pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root
    readonly property bool active: picker.running
    // Last picked colour (hex); empty until something is picked.
    property string lastColor: ""
    signal picked(string color)

    function pick() {
        if (picker.running) return
        PopupManager.close()
        picker.running = true
    }

    Process {
        id: picker
        command: ["hyprpicker", "--autocopy", "--format=hex"]
        stdout: StdioCollector {
            onStreamFinished: {
                const color = text.trim().split("\n").pop()
                if (!/^#[0-9a-fA-F]{6,8}$/.test(color)) return  // cancelled with Escape
                root.lastColor = color
                root.picked(color)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim()) console.warn("Color picker: " + text.trim())
        }
    }
}
