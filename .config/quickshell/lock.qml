//@ pragma UseQApplication
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "lockscreen"

ShellRoot {
    id: root
    readonly property bool validating: Quickshell.env("QS_LOCK_VALIDATE") === "1"
    LockState {
        id: lockState
        onAuthenticated: {
            finishUnlock.restart()
        }
    }
    WlSessionLock {
        id: lock
        locked: !root.validating
        WlSessionLockSurface {
            color: "#13202b"
            LockContent { anchors.fill: parent; state: lockState }
        }
    }
    // Keep the compositor lock held for the entire exit animation.
    Timer {
        id: finishUnlock
        interval: 260
        onTriggered: { lock.locked = false; Qt.callLater(Qt.quit) }
    }
    IpcHandler {
        target: "lock"
        function isSecure(): bool { return lock.secure }
    }
    Timer { interval: 1000; running: root.validating; onTriggered: Qt.quit() }
}
