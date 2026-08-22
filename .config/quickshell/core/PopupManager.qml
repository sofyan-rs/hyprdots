pragma Singleton
import Quickshell

Singleton {
    id: root

    property string activeId: ""
    property var activeScreen: null

    function toggle(id, screen) {
        if (activeId === id && activeScreen === screen) {
            activeId = ""
            activeScreen = null
        } else {
            activeId = id
            activeScreen = screen
        }
    }

    function close() {
        activeId = ""
        activeScreen = null
    }
}
