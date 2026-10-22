import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import "../core"
import "../clock"
import "../controlcenter"
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
    color: Colors.glassBar

    MouseArea {
        anchors.fill: parent
        onClicked: {
            PopupManager.close()
        }
    }

    PopupCatcher {
        barScreen: bar.barScreen
    }

    Process {
        id: overviewProc
        command: ["hyprctl", "dispatch", 'hl.plugin.scrolloverview.overview("toggle all")']
    }

    RowLayout {
        id: statusRow
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Tray {
            id: statusTray
            barWindow: bar
            flat: true
            onExpandedChanged: {
                if (!expanded && PopupManager.activeId === "aiusage" && PopupManager.activeScreen === bar.barScreen)
                    PopupManager.close()
            }
            additionalItems: [
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
                },

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
                        color: CaffeineState.active ? Colors.accent : Colors.fg
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
                        visible: statusTray.expanded && caffeineMouse.containsMouse && caffeineButton.tooltipReady
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
                            color: Colors.glass
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
                },

                Usage {
                    barScreen: bar.barScreen
                }
            ]
        }

        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 18
            color: Colors.border
        }

        Volume {
            barScreen: bar.barScreen
            flat: true
            compact: true
            implicitWidth: 26
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
        Pill {
            id: overviewButton
            property bool tooltipReady: false
            flat: true
            implicitWidth: 26
            Accessible.role: Accessible.Button
            Accessible.name: "Open ScrollOverview"

            Text {
                anchors.centerIn: parent
                text: "\ue9b0"
                font.family: Colors.iconFontFamily
                font.pixelSize: 18
                color: Colors.fg
            }

            MouseArea {
                id: overviewMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: overviewTooltipDelay.restart()
                onExited: {
                    overviewTooltipDelay.stop()
                    overviewButton.tooltipReady = false
                }
                onClicked: {
                    overviewTooltipDelay.stop()
                    overviewButton.tooltipReady = false
                    if (!overviewProc.running)
                        overviewProc.running = true
                }
            }

            Timer {
                id: overviewTooltipDelay
                interval: 600
                onTriggered: overviewButton.tooltipReady = true
            }

            PanelWindow {
                property real rightMargin: 6
                screen: bar.barScreen
                visible: overviewMouse.containsMouse && overviewButton.tooltipReady
                anchors { top: true; right: true }
                margins.top: Colors.barHeight + Colors.popupTopGap
                margins.right: rightMargin
                onVisibleChanged: if (visible) {
                    const p = overviewButton.mapToItem(null, overviewButton.width, 0)
                    rightMargin = Math.max(6, bar.barScreen.width - p.x)
                }
                implicitWidth: overviewTooltipLabel.implicitWidth + 24
                implicitHeight: 34
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                mask: Region {}
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "quickshell-scrolloverview-tooltip"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                Rectangle {
                    anchors.fill: parent
                    radius: 8
                    color: Colors.glass
                    border.width: 1
                    border.color: Colors.border
                }

                Text {
                    id: overviewTooltipLabel
                    anchors.centerIn: parent
                    text: "ScrollOverview · Super+Tab"
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: Colors.fg
                }
            }
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

        Workspaces {
            id: workspaces
            barScreen: bar.barScreen
        }

        Text {
            readonly property var toplevel: ToplevelManager.activeToplevel
            visible: text !== ""
            text: toplevel ? (toplevel.title || toplevel.appId || "") : ""
            Layout.maximumWidth: Math.max(0, bar.width * 0.4)
            elide: Text.ElideRight
            font.family: Colors.fontFamily
            font.pixelSize: Colors.fontSize
            font.bold: true
            color: Colors.fg
        }
    }

    ControlCenter {
        id: center
        barScreen: bar.barScreen
        triggerItem: controlCenterTrigger
    }
}
