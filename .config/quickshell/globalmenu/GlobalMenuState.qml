pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../core"
Singleton {
    id: root
    property var state: ({address: "", class: "", pid: 0, menus: [], token: ""})
    IpcHandler {
        target: "globalmenu"
        function status(): string { return JSON.stringify({app: root.state.class, menus: root.state.menus.map(menu => menu.label)}) }
        function refresh(): void { bridge.running = false; restart.restart() }
    }
    function request(action, id, parentId) { bridge.write(JSON.stringify({action: action, id: id, parentId: parentId, token: state.token}) + "\n") }
    Process {
        id: bridge
        command: ["python3", Quickshell.shellPath("globalmenu/bridge.py")]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: data => {
                try {
                    const next = JSON.parse(data)
                    if ((next.token !== root.state.token || next.menus.length === 0) && PopupManager.activeId === "globalmenu") PopupManager.close()
                    root.state = next
                } catch (e) { }
            }
        }
        stderr: SplitParser { onRead: data => console.warn(data) }
        onExited: restart.restart()
    }
    Timer { id: restart; interval: 2000; onTriggered: bridge.running = true }
}
