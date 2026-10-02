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

    readonly property var workspaceNames: {
        const names = ["1", "2", "3", "4", "5", "6"]
        const extras = Hyprland.workspaces.values.filter(ws => ws.monitor === root.monitor && !names.includes(ws.name))
        return names.concat(extras.map(ws => ws.name))
    }

    implicitWidth: row.implicitWidth
    implicitHeight: 30
    color: "transparent"
    border.width: 0
    border.color: Colors.border
    radius: 7

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
        spacing: 3

        Repeater {
            model: root.workspaceNames

            delegate: Rectangle {
                id: wsButton

                required property var modelData

                readonly property var workspace: Hyprland.workspaces.values.find(ws => ws.name === modelData && ws.monitor === root.monitor)
                readonly property bool isFocused: workspace ? workspace.focused : false
                readonly property bool isVisible: workspace ? workspace.active && !workspace.focused : false

                Layout.preferredWidth: Math.max(30, label.implicitWidth + 12)
                Layout.preferredHeight: 30
                radius: 7
                color: isFocused ? Colors.accent : (isVisible ? Colors.wsFocusedBg : "transparent")

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: wsButton.modelData
                    font.family: Colors.fontFamily
                    font.pixelSize: Colors.fontSize
                    font.bold: wsButton.isFocused
                    color: wsButton.isFocused ? Colors.accentText : Colors.fg
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.goToWorkspace(wsButton.modelData)
                }
            }
        }
    }
}
