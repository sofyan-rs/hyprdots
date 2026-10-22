import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root
    property bool open: false
    readonly property var provider: UsageState.current
    implicitHeight: column.implicitHeight + 36
    transformOrigin: Item.TopRight
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

    radius: 16
    color: Colors.glass
    border.width: 1
    border.color: Colors.border

    ColumnLayout {
        id: column
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "\uf06c"
                font.family: Colors.iconFontFamily
                font.pixelSize: 22
                color: Colors.accent
            }
            Text { text: "AI Agent Usage"; font.family: Colors.fontFamily; font.pixelSize: 13; font.bold: true; color: Colors.fg }
            Item { Layout.fillWidth: true }
            Rectangle {
                implicitWidth: 30
                implicitHeight: 30
                radius: 8
                color: refreshMouse.containsMouse ? Colors.surfaceHover : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "\ue5d5"
                    font.family: Colors.iconFontFamily
                    font.pixelSize: 19
                    color: root.provider.busy ? Colors.fgAlt : Colors.fg
                    RotationAnimator on rotation { from: 0; to: 360; duration: 1200; loops: Animation.Infinite; running: root.provider.busy }
                }
                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.provider.busy
                    onClicked: root.provider.refresh(true)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: UsageState.enabledProviders.length > 1
            implicitHeight: 34
            radius: 10
            color: Colors.surface
            RowLayout {
                anchors { fill: parent; margins: 3 }
                spacing: 3
                Repeater {
                    model: UsageState.enabledProviders
                    delegate: Rectangle {
                        id: tab
                        required property var modelData
                        readonly property bool selected: root.provider === modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: selected ? Colors.surfaceAlt : tabMouse.containsMouse ? Colors.surfaceHover : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 6; height: 6; radius: 3
                                color: tab.modelData.error ? Colors.accentLight : Colors.accent
                            }
                            Text {
                                text: tab.modelData.name
                                font.family: Colors.fontFamily
                                font.pixelSize: 12
                                font.bold: tab.selected
                                color: tab.selected ? Colors.fg : Colors.fgAlt
                            }
                        }
                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: UsageState.currentTab = tab.modelData.key
                        }
                    }
                }
            }
        }

        Text {
            text: UsageState.enabledProviders.length > 1 ? "Usage remaining" : root.provider.name + " · Usage remaining"
            font.family: Colors.fontFamily
            font.pixelSize: 11
            color: Colors.fgAlt
        }

        Repeater {
            model: ["session", "weekly"]
            delegate: ColumnLayout {
                id: quota
                required property string modelData
                readonly property var window: modelData === "session" ? root.provider.session : root.provider.weekly
                readonly property color fillColor: window && window.usedPercent >= 90 ? Colors.secondary : Colors.accent
                Layout.fillWidth: true
                spacing: 7
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: quota.modelData === "session" ? "Session · 5hr" : "Weekly"
                        font.family: Colors.fontFamily
                        font.pixelSize: 12
                        color: Colors.fg
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: UsageState.remaining(quota.window)
                        font.family: Colors.fontFamily
                        font.pixelSize: 14
                        font.bold: true
                        color: quota.fillColor
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 7
                    radius: 3.5
                    color: Colors.border
                    Rectangle {
                        width: parent.width * (quota.window ? (100 - quota.window.usedPercent) / 100 : 0)
                        height: parent.height
                        radius: parent.radius
                        color: quota.fillColor
                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    }
                }
                Text {
                    text: quota.window && quota.window.resetLabel ? "Reset " + quota.window.resetLabel : "Reset date unavailable"
                    font.family: Colors.fontFamily
                    font.pixelSize: 10
                    color: Colors.fgAlt
                }
                Text {
                    text: UsageState.countdown(quota.window)
                    font.family: Colors.fontFamily
                    font.pixelSize: 10
                    color: Colors.fgAlt
                }
            }
        }

        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.border }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: root.provider.error ? (root.provider.updatedAt ? "Last known data · " : "") + root.provider.error
                : root.provider.busy ? "Refreshing usage…"
                : root.provider.updatedAt ? "Updated " + Qt.formatDateTime(new Date(root.provider.updatedAt * 1000), "HH:mm") + " · Refreshes every 5 min"
                : "Fetching " + root.provider.name + " usage…"
            font.family: Colors.fontFamily
            font.pixelSize: 10
            color: root.provider.error ? Colors.accentLight : Colors.fgAlt
        }
    }
}
