import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import "../core"

Row {
    id: root

    required property var barWindow
    property bool expanded: false

    spacing: 5

    Pill {
        id: togglePill
        implicitWidth: toggleIcon.implicitWidth + 20

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
            onClicked: root.expanded = !root.expanded
        }
    }

    Pill {
        id: trayPill
        clip: true
        visible: width > 0
        implicitWidth: root.expanded ? (trayRow.implicitWidth + 20) : 0

        Behavior on implicitWidth {
            NumberAnimation { duration: 220; easing.type: Easing.InOutQuad }
        }

        Row {
            id: trayRow
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: SystemTray.items

                delegate: IconImage {
                    id: trayIcon

                    required property var modelData

                    implicitWidth: 15
                    implicitHeight: 15
                    source: modelData.icon

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton)
                                trayIcon.modelData.display(root.barWindow, mouse.x, mouse.y)
                            else
                                trayIcon.modelData.activate()
                        }
                    }
                }
            }
        }
    }
}
