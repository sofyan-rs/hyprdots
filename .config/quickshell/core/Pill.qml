import QtQuick
import QtQuick.Effects

Item {
    id: root

    property color bgColor: Colors.bgAlt
    property alias radius: bg.radius

    implicitHeight: 28

    Rectangle {
        id: bg
        anchors.fill: parent
        color: root.bgColor
        border.width: 1
        border.color: Colors.border
        radius: Colors.radius
    }

    MultiEffect {
        anchors.fill: bg
        source: bg
        autoPaddingEnabled: true
        shadowEnabled: true
        shadowVerticalOffset: 2
        shadowBlur: 0.08
        shadowOpacity: 0.5
        shadowColor: Colors.shadow
    }
}
