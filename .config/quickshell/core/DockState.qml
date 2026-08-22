pragma Singleton
import Quickshell

Singleton {
    id: root

    property bool open: false
    property var screen: null

    function toggle(s) {
        if (root.open && root.screen === s) {
            root.open = false
        } else {
            root.screen = s
            root.open = true
        }
    }

    function close() {
        root.open = false
    }
}
