import QtQuick
import QtQuick.Layouts
import "../core"
Rectangle {
    id: root
    property string title: ""
    property string subtitle: ""
    property string icon: ""
    property color iconColor: root.highlighted ? Colors.bg : Colors.fg
    property color iconBackgroundColor: root.highlighted ? Colors.fg : Colors.surfaceHover
    property color titleColor: Colors.fg
    property string trailing: "\ue5cc"
    property bool highlighted: false
    property bool flat: false
    property real verticalPadding: 0
    signal clicked()
    implicitHeight: Math.max(56, row.implicitHeight + verticalPadding * 2)
    radius: 12
    color: flat ? "transparent" : (mouse.containsMouse ? Colors.border : Colors.surface)
    MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
    RowLayout {
        id: row
        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 12
        anchors.topMargin: root.verticalPadding
        anchors.bottomMargin: root.verticalPadding
        Rectangle {
            visible: root.icon !== ""
            Layout.preferredWidth: 36; Layout.preferredHeight: 36
            radius: 10
            color: root.iconBackgroundColor
            Text { anchors.centerIn: parent; text: root.icon; font.family: Colors.iconFontFamily; font.pixelSize: 21; color: root.iconColor }
        }
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            CcText { Layout.fillWidth: true; text: root.title; font.bold: true; color: root.titleColor }
            CcText { Layout.fillWidth: true; visible: text !== ""; text: root.subtitle; font.pixelSize: 11; color: Colors.fgAlt }
        }
        Text { visible: text !== ""; text: root.trailing; font.family: Colors.iconFontFamily; font.pixelSize: 20; color: Colors.fgAlt }
    }
}
