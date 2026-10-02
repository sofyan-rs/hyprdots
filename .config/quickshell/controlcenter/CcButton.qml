import QtQuick
import QtQuick.Layouts
import "../core"
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property bool primary: false
    property bool danger: false
    property real horizontalPadding: 12
    readonly property real contentHeight: row.implicitHeight
    signal clicked()
    implicitWidth: row.implicitWidth + horizontalPadding * 2
    implicitHeight: 36
    radius: 9
    color: primary ? Colors.fg : (mouse.containsMouse ? Colors.border : Colors.surfaceAlt)
    opacity: enabled ? 1 : 0.45
    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Text {
            visible: root.icon !== ""
            text: root.icon
            font.family: Colors.iconFontFamily
            font.pixelSize: 19
            color: root.primary ? Colors.bg : (root.danger ? Colors.accent : Colors.fg)
        }
        CcText { visible: root.text !== ""; text: root.text; font.pixelSize: 12; color: root.primary ? Colors.bg : (root.danger ? Colors.accent : Colors.fg) }
    }
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
