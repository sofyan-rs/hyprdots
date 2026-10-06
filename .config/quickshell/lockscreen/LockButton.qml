import QtQuick
import QtQuick.Controls
import "../core"

Button {
    id: root
    property string glyph: ""
    property bool primary: false
    property real uiScale: 1
    property color glyphColor: primary ? "#151515" : "#f3f3f3"
    property real glyphSize: 20 * uiScale
    implicitHeight: 42 * uiScale
    implicitWidth: Math.max(44 * uiScale, content.implicitWidth + 30 * uiScale)
    padding: 0
    hoverEnabled: true
    opacity: enabled ? 1 : 0.55
    background: Rectangle {
        radius: 11 * root.uiScale
        color: root.primary ? (root.down ? "#cccccc" : "#f3f3f3") : (root.hovered ? "#553f4952" : "#35313c45")
        border.width: root.activeFocus ? 2 : 0
        border.color: "#eeeeee"
    }
    // Controls resize contentItem to the button's available rectangle. Keep the
    // label in an inner row so it stays centered instead of starting at the left.
    contentItem: Item {
        id: content
        implicitWidth: label.implicitWidth
        implicitHeight: label.implicitHeight
        Row {
            id: label
            spacing: 9 * root.uiScale
            anchors.centerIn: parent
            Text {
                visible: root.glyph !== ""
                text: root.glyph
                font.family: Colors.iconFontFamily
                font.pixelSize: root.glyphSize
                color: root.glyphColor
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: root.text !== ""
                text: root.text
                font.family: Colors.fontFamily
                font.pixelSize: 12 * root.uiScale
                color: root.primary ? "#151515" : "#f3f3f3"
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
