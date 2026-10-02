import QtQuick

Item {
    id: root

    property bool flat: false
    property color bgColor: Colors.bgAlt
    property alias radius: bg.radius

    implicitHeight: 28

    Rectangle {
        id: bg
        anchors.fill: parent
        color: root.flat ? "transparent" : root.bgColor
        border.width: root.flat ? 0 : 1
        border.color: Colors.border
        radius: Colors.radius
    }
}
