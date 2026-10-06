import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import "../core"
import "../clock"
import "../controlcenter"
import "../globalmenu"
import "../volume"
import "../aiusage"

PanelWindow {
    id: bar

    required property var modelData
    readonly property var barScreen: modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Colors.barHeight
    color: Colors.bg

    MouseArea {
        anchors.fill: parent
        onClicked: {
            PopupManager.close()
        }
    }

    PopupCatcher {
        barScreen: bar.barScreen
    }

    RowLayout {
        id: statusRow
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Tray {
            barWindow: bar
            flat: true
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 18
            color: Colors.border
        }

        Pill {
            id: colorPickerButton
            flat: true
            implicitWidth: 26

            Text {
                anchors.centerIn: parent
                text: "\ue3b8"
                font.family: Colors.iconFontFamily
                font.pixelSize: 18
                color: ColorPickerState.active ? Colors.accent : Colors.fg
            }

            MouseArea {
                id: colorPickerMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ColorPickerState.pick()
            }
        }

        Pill {
            id: caffeineButton
            property bool tooltipReady: false
            flat: true
            implicitWidth: 26
            Text {
                anchors.centerIn: parent
                text: "\uefef"
                font.family: Colors.iconFontFamily
                font.pixelSize: 18
                color: CaffeineState.active ? Colors.accent : Colors.fgAlt
            }
            MouseArea {
                id: caffeineMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: CaffeineState.toggle()
                onEntered: tooltipDelay.restart()
                onExited: {
                    tooltipDelay.stop()
                    caffeineButton.tooltipReady = false
                }
            }
            Timer {
                id: tooltipDelay
                interval: 600
                onTriggered: caffeineButton.tooltipReady = true
            }
            PanelWindow {
                id: caffeineTooltip
                property real rightMargin: 6
                screen: bar.barScreen
                visible: caffeineMouse.containsMouse && caffeineButton.tooltipReady
                anchors { top: true; right: true }
                margins.top: Colors.barHeight + Colors.popupTopGap
                margins.right: rightMargin
                onVisibleChanged: if (visible) {
                    const p = caffeineButton.mapToItem(null, caffeineButton.width, 0)
                    rightMargin = Math.max(6, bar.barScreen.width - p.x)
                }
                implicitWidth: tooltipLabel.implicitWidth + 24
                implicitHeight: 34
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                mask: Region {}
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "quickshell-caffeine-tooltip"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: Colors.bgAlt
                    border.width: 1
                    border.color: Colors.border
                }
                Text {
                    id: tooltipLabel
                    anchors.centerIn: parent
                    text: CaffeineState.active ? "Caffeine on · Auto sleep off" : "Caffeine off · Auto sleep after 30 min"
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: Colors.fg
                }
            }
        }


        Usage {
            barScreen: bar.barScreen
        }

        Repeater {
            model: ["wifi", "bluetooth"]
            delegate: Pill {
                required property string modelData
                flat: true
                implicitWidth: 26
                Text {
                    anchors.centerIn: parent
                    text: modelData === "wifi" ? (center.network.state.wired ? "\ue335" : "\ue63e") : (modelData === "bluetooth" ? "\ue1a7" : (center.muted ? "\ue04f" : "\ue050"))
                    font.family: Colors.iconFontFamily
                    font.pixelSize: 18
                    color: (modelData === "wifi" && !center.network.state.wired && !center.network.state.enabled) || (modelData === "bluetooth" && !center.bluetoothOn) ? Colors.fgAlt : Colors.fg
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: center.toggle(modelData === "volume" ? "hub" : "connections", modelData)
                    onDoubleClicked: mouse => {
                        mouse.accepted = true
                        center.toggle(modelData === "volume" ? "hub" : "connections", modelData)
                    }
                }
            }
        }


        Volume {
            barScreen: bar.barScreen
            flat: true
            compact: true
            implicitWidth: 26
        }

        Clock {
            barScreen: bar.barScreen
            flat: true
            dateFormat: "ddd dd MMM  hh:mm"
        }

        Pill {
            id: controlCenterTrigger
            flat: true
            implicitWidth: 32
            implicitHeight: 34

            Text {
                anchors.centerIn: parent
                text: "\ue429"
                font.family: Colors.iconFontFamily
                font.pixelSize: 20
                color: Colors.accent
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: center.toggle("hub", "")
                onDoubleClicked: mouse => {
                    mouse.accepted = true
                    center.toggle("hub", "")
                }
            }
        }
    }

    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12
        Item {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 30

            Text {
                anchors.centerIn: parent
                text: "⌘"
                font.family: Colors.fontFamily
                font.pixelSize: 22
                color: Colors.accent
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: PopupManager.toggle("launcher", bar.barScreen)
            }
        }

        GlobalMenu {
            barScreen: bar.barScreen
            maximumWidth: Math.max(0, workspaces.x - 60)
        }
    }
    Workspaces {
        id: workspaces
        barScreen: bar.barScreen
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
    }

    ControlCenter {
        id: center
        barScreen: bar.barScreen
        triggerItem: controlCenterTrigger
    }
}
