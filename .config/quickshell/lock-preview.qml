//@ pragma UseQApplication
import Quickshell
import QtQuick
import "lockscreen"
import QtQuick.Window

ShellRoot {
    LockState { id: lockState; preview: true }
    Window {
        id: window
        visible: true
        width: 1152; height: 720
        title: "Quickshell lock screen preview"
        LockContent { id: content; anchors.fill: parent; state: lockState }
        Timer {
            interval: 650
            running: Quickshell.env("QS_LOCK_PREVIEW_POWER") === "1"
            onTriggered: content.powerOpen = true
        }
        Timer {
            interval: 2500
            running: Quickshell.env("QS_LOCK_CAPTURE") !== ""
            onTriggered: content.grabToImage(result => { result.saveToFile(Quickshell.env("QS_LOCK_CAPTURE")); Qt.quit() })
        }
    }
}
