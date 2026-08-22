import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import "../core"

Pill {
    id: root

    required property var barScreen

    readonly property bool open: PopupManager.activeId === "bluetooth" && PopupManager.activeScreen === barScreen

    property bool powered: false
    property bool connected: false

    readonly property string icon: {
        if (!powered)
            return "\ue1a9"
        if (connected)
            return "\ue1a8"
        return "\ue1a7"
    }

    implicitWidth: label.implicitWidth + 20

    Text {
        id: label
        anchors.centerIn: parent
        text: root.icon
        font.family: Colors.iconFontFamily
        font.pixelSize: Colors.fontSize + 2
        color: root.connected ? Colors.fg : (root.powered ? Colors.fg : Colors.fgAlt)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: PopupManager.toggle("bluetooth", root.barScreen)
    }

    Process {
        id: powerProc
        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off"]
        stdout: SplitParser {
            onRead: line => root.powered = line.trim() === "on"
        }
    }

    Process {
        id: connectedProc
        command: ["sh", "-c", "bluetoothctl devices Connected"]
        property bool any: false
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line.trim() !== "")
                    connectedProc.any = true
            }
        }
        onRunningChanged: {
            if (running)
                any = false
        }
        onExited: root.connected = connectedProc.any
    }

    function refresh() {
        powerProc.running = true
        connectedProc.running = true
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

        anchors {
            top: true
            right: true
        }
        margins.top: Colors.barHeight + 2
        margins.right: rightMargin

        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight

        BluetoothPopup {
            id: content
            open: root.open
            onRefreshRequested: root.refresh()
        }
    }
}
