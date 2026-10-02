import QtQuick
import "../core"
Rectangle {
    id: root
    property bool checked: false
    signal clicked()
    implicitWidth: 38
    implicitHeight: 22
    radius: 11
    color: checked ? Colors.fg : Colors.border
    opacity: enabled ? 1 : 0.4
    Rectangle {
        width: 16; height: 16; radius: 8
        y: 3; x: root.checked ? root.width - width - 3 : 3
        color: root.checked ? Colors.bg : Colors.fgAlt
        Behavior on x { NumberAnimation { duration: 120 } }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
