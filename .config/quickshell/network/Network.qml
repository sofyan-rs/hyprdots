import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../core"

Pill {
    id: root

    required property var barScreen

    readonly property bool open: PopupManager.activeId === "network" && PopupManager.activeScreen === barScreen

    property string ethState: "disconnected"
    property string wifiState: "disconnected"
    property int wifiSignal: 0
    property bool wifiRadioOn: true

    readonly property string icon: {
        if (ethState === "connected")
            return ""
        if (!wifiRadioOn || wifiState === "disconnected")
            return ""
        if (wifiSignal >= 66)
            return ""
        if (wifiSignal >= 33)
            return ""
        return ""
    }

    implicitWidth: label.implicitWidth + 20

    Text {
        id: label
        anchors.centerIn: parent
        text: root.icon
        font.family: Colors.iconFontFamily
        font.pixelSize: Colors.fontSize + 2
        color: (root.ethState === "connected" || root.wifiState === "connected") ? Colors.fg : Colors.fgAlt
    }

    MouseArea {
        anchors.fill: parent
        onClicked: PopupManager.toggle("network", root.barScreen)
    }

    Process {
        id: statusProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION,DEVICE", "device"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const parts = line.split(":")
                if (parts.length < 4)
                    return
                const type = parts[0]
                const state = parts[1]
                if (type === "ethernet")
                    root.ethState = state === "connected" ? "connected" : "disconnected"
                if (type === "wifi")
                    root.wifiState = state === "connected" ? "connected" : "disconnected"
            }
        }
    }

    Process {
        id: radioProc
        command: ["nmcli", "radio", "wifi"]
        stdout: SplitParser {
            onRead: line => root.wifiRadioOn = line.trim() === "enabled"
        }
    }

    Process {
        id: signalProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,SIGNAL dev wifi list | grep '^yes:' | head -1 | cut -d: -f2"]
        stdout: SplitParser {
            onRead: line => {
                const v = parseInt(line.trim(), 10)
                root.wifiSignal = isNaN(v) ? 0 : v
            }
        }
    }

    function refresh() {
        statusProc.running = true
        radioProc.running = true
        signalProc.running = true
    }

    Timer {
        interval: 4000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    function updatePopupPosition() {
        const screenW = root.barScreen ? root.barScreen.width : 0
        const pos = root.mapToItem(null, root.width, 0)
        popup.rightMargin = Math.max(4, screenW - pos.x)
    }

    onOpenChanged: {
        if (open) {
            Qt.callLater(updatePopupPosition)
            refresh()
        }
    }

    PanelWindow {
        id: popup

        property real rightMargin: 20

        screen: root.barScreen
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        anchors {
            top: true
            right: true
        }
        margins.top: Colors.barHeight + 2
        margins.right: rightMargin

        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight

        NetworkPopup {
            id: content
            open: root.open
            onRefreshRequested: root.refresh()
        }
    }
}
