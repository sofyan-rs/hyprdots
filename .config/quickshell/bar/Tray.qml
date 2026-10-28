import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Effects
import "../core"

Row {
    id: root

    required property var barWindow
    property bool expanded: false
    property bool flat: false
    property alias additionalItems: extraControls.data

    spacing: root.flat ? 8 : 5
    // Hide the whole tray (chevron included) when there is nothing to show.
    readonly property bool hasItems: SystemTray.items.values.length > 0 || extraControls.children.length > 0
    visible: hasItems

    TrayMenu {
        id: contextMenu
        barWindow: root.barWindow
    }

    Pill {
        id: togglePill
        flat: root.flat
        implicitWidth: root.flat ? 26 : toggleIcon.implicitWidth + 20

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
            onClicked: {
                contextMenu.close()
                root.expanded = !root.expanded
            }
        }
    }

    Pill {
        id: trayPill
        flat: root.flat
        clip: true
        visible: width > 0
        implicitWidth: root.expanded ? (trayRow.implicitWidth + (root.flat ? 0 : 20)) : 0

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

                // Same 26px slot as the bar's icon pills so the spacing matches.
                delegate: Item {
                    id: trayIcon

                    required property var modelData

                    implicitWidth: root.flat ? 26 : 18
                    implicitHeight: 26
                    anchors.verticalCenter: parent.verticalCenter

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 18
                        source: trayIcon.modelData.icon

                        // Symbolic icons ship with a hardcoded dark fill; tint them to match the bar
                        layer.enabled: String(trayIcon.modelData.icon).indexOf("-symbolic") !== -1
                        layer.effect: MultiEffect {
                            brightness: 1.0
                            colorization: 1.0
                            colorizationColor: Colors.fg
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton || trayIcon.modelData.onlyMenu) {
                                const pos = trayIcon.mapToItem(root.barWindow.contentItem, 0, trayIcon.height)
                                contextMenu.show(trayIcon.modelData, pos.x)
                            } else {
                                contextMenu.close()
                                trayIcon.modelData.activate()
                            }
                        }
                    }
                }
            }

            Row {
                id: extraControls
                spacing: 8
                visible: children.length > 0
            }
        }
    }
}
