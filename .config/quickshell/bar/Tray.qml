import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import "../core"

Row {
    id: root

    required property var barWindow
    property bool expanded: false
    property bool flat: false

    spacing: root.flat ? 8 : 5

    Pill {
        id: togglePill
        flat: root.flat
        implicitWidth: toggleIcon.implicitWidth + (root.flat ? 8 : 20)

        Text {
            id: toggleIcon
            anchors.centerIn: parent
            text: root.expanded ? "\ue5cc" : "\ue5cb"
            font.family: Colors.iconFontFamily
            font.pixelSize: Colors.fontSize + 2
            color: Colors.fg
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }
    }

    Pill {
        id: trayPill
        flat: root.flat
        clip: true
        visible: width > 0
        implicitWidth: root.expanded ? (trayRow.implicitWidth + (root.flat ? 4 : 20)) : 0

        Behavior on implicitWidth {
            NumberAnimation { duration: 220; easing.type: Easing.InOutQuad }
        }

        Row {
            id: trayRow
            anchors.left: parent.left
            anchors.leftMargin: root.flat ? 0 : 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Repeater {
                model: SystemTray.items

                delegate: IconImage {
                    id: trayIcon

                    required property var modelData

                    implicitWidth: 18
                    implicitHeight: 18
                    source: modelData.icon

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                const pos = trayIcon.mapToItem(root.barWindow.contentItem, mouse.x, mouse.y)
                                trayIcon.modelData.display(root.barWindow, pos.x, pos.y)
                            } else {
                                trayIcon.modelData.activate()
                            }
                        }
                    }
                }
            }
        }
    }
}
