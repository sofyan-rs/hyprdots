import QtQuick
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root
    property bool open: false
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
    color: Colors.bgAlt
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
            ColumnLayout {
                spacing: 2
                Text { text: "AI Agent Usage"; font.family: Colors.fontFamily; font.pixelSize: 13; font.bold: true; color: Colors.fg }
                Text { text: "Codex"; font.family: Colors.fontFamily; font.pixelSize: 11; color: Colors.fgAlt }
            }
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
                    color: UsageState.busy ? Colors.fgAlt : Colors.fg
                    RotationAnimator on rotation { from: 0; to: 360; duration: 1200; loops: Animation.Infinite; running: UsageState.busy }
                }
                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !UsageState.busy
                    onClicked: UsageState.refresh()
                }
            }
        }

        Text {
            text: "Usage remaining"
            font.family: Colors.fontFamily
            font.pixelSize: 11
            color: Colors.fgAlt
        }

        Repeater {
            model: ["session", "weekly"]
            delegate: ColumnLayout {
                id: quota
                required property string modelData
                readonly property var window: modelData === "session" ? UsageState.session : UsageState.weekly
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
            text: UsageState.error ? (UsageState.updatedAt ? "Last known data · " : "") + UsageState.error
                : UsageState.busy ? "Refreshing usage…"
                : UsageState.updatedAt ? "Updated " + Qt.formatDateTime(new Date(UsageState.updatedAt * 1000), "HH:mm") + " · Refreshes every 5 min"
                : "Fetching Codex usage…"
            font.family: Colors.fontFamily
            font.pixelSize: 10
            color: UsageState.error ? Colors.accentLight : Colors.fgAlt
        }
    }
}
