import QtQuick
import "../core"

Rectangle {
    id: btn

    property string glyph: ""
    property bool primary: false
    property bool active: false
    property bool small: false
    property bool enabled: true
    signal clicked()

    implicitWidth: primary ? 40 : (small ? 26 : 32)
    implicitHeight: implicitWidth
    radius: implicitWidth / 2
    color: primary ? Colors.accent : (active ? Qt.alpha(Colors.accent, 0.16) : "transparent")
    border.width: primary ? 0 : 1
    border.color: active ? Colors.accent : Colors.border
    opacity: enabled ? 1 : 0.35

    Behavior on color {
        ColorAnimation { duration: 120 }
    }

    Text {
        anchors.centerIn: parent
        text: btn.glyph
        font.family: Colors.iconFontFamily
        font.pixelSize: btn.primary ? 20 : (btn.small ? 13 : 16)
        color: btn.primary ? Colors.accentText : (btn.active ? Colors.accent : Colors.fg)
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }

    scale: btn.enabled && clickArea.pressed ? 0.92 : 1
    Behavior on scale {
        NumberAnimation { duration: 100 }
    }
}
