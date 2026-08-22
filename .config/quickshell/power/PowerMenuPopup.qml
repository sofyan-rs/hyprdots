import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    property bool open: false

    readonly property color dangerColor: "#f0454c"

    transformOrigin: Item.TopRight

    implicitWidth: 200
    implicitHeight: column.implicitHeight + 16

    opacity: open ? 1 : 0
    scale: open ? 1 : 0.92
    y: open ? 0 : -14

    Behavior on opacity {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    Process {
        id: actionProc
    }

    function runAction(command) {
        PopupManager.close()
        actionProc.command = command
        actionProc.running = true
    }

    readonly property var items: [
        { icon: "\ue899", label: "Lock", command: ["hyprlock"] },
        { icon: "\ue51c", label: "Suspend", command: ["systemctl", "suspend"] },
        { icon: "\ue9ba", label: "Logout", command: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
        { icon: "\uf8c7", label: "Shutdown", command: ["systemctl", "poweroff"], danger: true },
        { icon: "\uf053", label: "Reboot", command: ["systemctl", "reboot"] }
    ]

    Rectangle {
        anchors.fill: parent
        radius: Colors.radius
        color: Colors.bgAlt
        border.width: 1
        border.color: Colors.border
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 8
        spacing: 4

        Repeater {
            model: root.items

            delegate: Rectangle {
                id: menuRow

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: 36
                radius: Colors.radius
                color: itemArea.containsMouse ? Colors.secondary : "transparent"

                Behavior on color {
                    ColorAnimation { duration: 100 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Item {
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            anchors.centerIn: parent
                            text: menuRow.modelData.icon
                            font.family: Colors.iconFontFamily
                            font.pixelSize: Colors.fontSize
                            color: itemArea.containsMouse ? Colors.accentText : (menuRow.modelData.danger ? root.dangerColor : Colors.fg)
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        horizontalAlignment: Text.AlignLeft
                        text: menuRow.modelData.label
                        font.family: Colors.fontFamily
                        font.pixelSize: Colors.fontSize
                        font.bold: true
                        color: itemArea.containsMouse ? Colors.accentText : (menuRow.modelData.danger ? root.dangerColor : Colors.fg)
                    }
                }

                MouseArea {
                    id: itemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.runAction(menuRow.modelData.command)
                }
            }
        }
    }
}
