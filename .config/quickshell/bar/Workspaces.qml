import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root

    required property var barScreen

    readonly property var monitor: Hyprland.monitorFor(barScreen)

    function goToWorkspace(name) {
        dispatchProc.running = false
        dispatchProc.command = ["hyprctl", "dispatch", "hl.dsp.focus({workspace = '" + name + "'})"]
        dispatchProc.running = true
    }

    implicitWidth: row.implicitWidth + 5
    implicitHeight: 28
    color: Colors.bgAlt
    border.width: 1
    border.color: Colors.border
    radius: Colors.radius

    Process {
        id: dispatchProc
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: event => {
            root.goToWorkspace(event.angleDelta.y > 0 ? "e-1" : "e+1")
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: Hyprland.workspaces.values.filter(ws => ws.monitor === root.monitor)

            delegate: Rectangle {
                id: wsButton

                required property var modelData

                readonly property bool isFocused: modelData.focused
                readonly property bool isVisible: modelData.active && !modelData.focused

                Layout.preferredWidth: label.implicitWidth + 12
                Layout.preferredHeight: 22
                radius: Colors.radius
                color: isFocused ? Colors.secondary : (isVisible ? Colors.wsFocusedBg : "transparent")

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: wsButton.modelData.name
                    font.family: Colors.fontFamily
                    font.pixelSize: Colors.fontSize
                    font.bold: true
                    color: wsButton.isFocused ? Colors.accentText : Colors.fg
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.goToWorkspace(wsButton.modelData.name)
                }
            }
        }
    }
}
