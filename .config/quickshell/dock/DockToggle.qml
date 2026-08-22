import Quickshell
import QtQuick
import "../core"

Pill {
    id: root

    required property var barScreen

    readonly property bool open: DockState.open && DockState.screen === barScreen

    implicitWidth: label.implicitWidth + 20

    Text {
        id: label
        anchors.centerIn: parent
        text: ""
        font.family: Colors.iconFontFamily
        font.pixelSize: Colors.fontSize + 2
        color: root.open ? Colors.accent : Colors.fg
    }

    MouseArea {
        anchors.fill: parent
        onClicked: DockState.toggle(root.barScreen)
    }
}
