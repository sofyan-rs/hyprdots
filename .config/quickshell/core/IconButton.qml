import QtQuick
import Quickshell.Io

Pill {
    id: root

    property string icon: ""
    property color fgColor: Colors.fg
    property var command: []
    property var rightCommand: []

    implicitWidth: label.implicitWidth + 20

    Text {
        id: label
        anchors.centerIn: parent
        text: root.icon
        font.family: Colors.iconFontFamily
        font.pixelSize: Colors.fontSize + 2
        color: root.fgColor
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton && root.rightCommand.length > 0) {
                rightProc.running = false
                rightProc.command = root.rightCommand
                rightProc.running = true
            } else if (root.command.length > 0) {
                leftProc.running = false
                leftProc.command = root.command
                leftProc.running = true
            }
        }
    }

    Process { id: leftProc }
    Process { id: rightProc }
}
