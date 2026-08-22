import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    required property var barScreen
    property bool open: false

    transformOrigin: Item.TopRight

    implicitWidth: 240
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
        id: randomProc
        command: ["waypaper", "--random"]
    }

    readonly property var items: [
        { icon: "\ue043", label: "Randomize", action: "random" },
        { icon: "\ue1bc", label: "Select wallpaper", action: "select" }
    ]

    function runAction(action) {
        PopupManager.close()
        if (action === "random") {
            randomProc.running = true
        } else if (action === "select") {
            PopupManager.toggle("wallpaper", root.barScreen)
        }
    }

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
                            color: itemArea.containsMouse ? Colors.accentText : Colors.fg
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
                        color: itemArea.containsMouse ? Colors.accentText : Colors.fg
                    }
                }

                MouseArea {
                    id: itemArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.runAction(menuRow.modelData.action)
                }
            }
        }
    }
}
