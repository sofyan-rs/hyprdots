import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    property bool open: false

    transformOrigin: Item.TopRight

    implicitWidth: 320
    implicitHeight: Math.min(420, column.implicitHeight + 32)

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
        anchors.margins: 16
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: "Notifications"
                font.family: Colors.fontFamily
                font.pixelSize: Colors.fontSize
                font.bold: true
                color: Colors.fg
            }

            Text {
                visible: NotificationHub.notifications.values.length > 0
                text: "Clear all"
                font.family: Colors.fontFamily
                font.pixelSize: 12
                color: Colors.accent

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    onClicked: NotificationHub.dismissAll()
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: NotificationHub.notifications.values.length === 0
            text: "No notifications"
            font.family: Colors.fontFamily
            font.pixelSize: Colors.fontSize
            color: Colors.fgAlt
            horizontalAlignment: Text.AlignHCenter
            topPadding: 12
            bottomPadding: 12
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            implicitHeight: Math.min(list.implicitHeight, 260)
            clip: true
            contentWidth: width
            contentHeight: list.implicitHeight
            visible: NotificationHub.notifications.values.length > 0
            opacity: NotificationHub.clearing ? 0 : 1

            Behavior on opacity {
                NumberAnimation { duration: 120 }
            }

            ColumnLayout {
                id: list
                width: flick.width
                spacing: 8

                Repeater {
                    model: NotificationHub.notifications.values

                    delegate: Rectangle {
                        id: row

                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: rowContent.implicitHeight + 16
                        radius: Colors.radius
                        color: Colors.bg
                        border.width: 1
                        border.color: Colors.border

                        ColumnLayout {
                            id: rowContent
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 8
                            spacing: 2

                            RowLayout {
                                Layout.fillWidth: true

                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.appName || "Notification"
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 11
                                    font.bold: true
                                    color: Colors.fgAlt
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "\ue5cd"
                                    font.family: Colors.iconFontFamily
                                    font.pixelSize: 11
                                    color: Colors.fgAlt

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        onClicked: row.modelData.tracked = false
                                    }
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.summary
                                font.family: Colors.fontFamily
                                font.pixelSize: Colors.fontSize
                                font.bold: true
                                color: Colors.fg
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: row.modelData.body
                                font.family: Colors.fontFamily
                                font.pixelSize: 12
                                color: Colors.fgAlt
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }
}
