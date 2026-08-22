import Quickshell
import QtQuick
import "../core"

Pill {
    id: root

    required property var barScreen

    bgColor: Colors.accent
    implicitWidth: label.implicitWidth + 20

    Text {
        id: label
        anchors.centerIn: parent
        text: "\ue5c3"
        font.family: Colors.iconFontFamily
        font.pixelSize: Colors.fontSize + 2
        color: Colors.accentText
    }

    MouseArea {
        anchors.fill: parent
        onClicked: PopupManager.toggle("launcher", root.barScreen)
    }
}
