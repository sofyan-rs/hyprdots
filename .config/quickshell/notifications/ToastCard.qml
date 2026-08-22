import Quickshell.Services.Notifications
import QtQuick
import "../core"

Item {
    id: root

    required property var notification
    property bool shown: false

    implicitWidth: 320
    implicitHeight: shown ? card.implicitHeight : 0
    clip: true

    opacity: shown ? 1 : 0
    x: shown ? 0 : 40

    Behavior on opacity {
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    Behavior on x {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

    Component.onCompleted: shown = true

    Timer {
        interval: root.notification && root.notification.expireTimeout > 0 ? root.notification.expireTimeout : 5000
        running: true
        onTriggered: root.shown = false
    }

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: content.implicitHeight + 24
        radius: Colors.radius
        color: Colors.bgAlt
        border.width: 1
        border.color: Colors.border

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 3
            radius: 2
            color: root.notification && root.notification.urgency === NotificationUrgency.Critical ? Colors.secondary : Colors.accent
        }

        Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            anchors.leftMargin: 16
            spacing: 4

            Row {
                width: parent.width
                spacing: 6

                Text {
                    width: parent.width - closeIcon.width - 6
                    text: root.notification ? (root.notification.appName || root.notification.summary) : ""
                    font.family: Colors.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: Colors.fgAlt
                    elide: Text.ElideRight
                }

                Text {
                    id: closeIcon
                    text: "\ue5cd"
                    font.family: Colors.iconFontFamily
                    font.pixelSize: 12
                    color: Colors.fgAlt

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        onClicked: {
                            root.shown = false
                            if (root.notification)
                                root.notification.dismiss()
                        }
                    }
                }
            }

            Text {
                width: parent.width
                text: root.notification ? root.notification.summary : ""
                font.family: Colors.fontFamily
                font.pixelSize: Colors.fontSize
                font.bold: true
                color: Colors.fg
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text.length > 0
                text: root.notification ? root.notification.body : ""
                font.family: Colors.fontFamily
                font.pixelSize: 13
                color: Colors.fgAlt
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }
    }
}
