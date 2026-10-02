import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import "../core"

Item {
    id: root

    required property var notification
    property bool shown: false
    property real remaining: 1
    readonly property date receivedAt: new Date()
    readonly property int timeout: notification && notification.expireTimeout > 0 ? notification.expireTimeout : 5000
    readonly property bool persistent: notification && notification.expireTimeout === 0
    readonly property color highlight: notification && notification.urgency === NotificationUrgency.Critical ? Colors.secondary : Colors.accent
    readonly property string ageLabel: {
        const minutes = Math.max(0, Math.floor((ageClock.date.getTime() - receivedAt.getTime()) / 60000))
        if (minutes === 0) return "now"
        if (minutes < 60) return minutes + "m ago"
        return Math.floor(minutes / 60) + "h ago"
    }

    implicitWidth: 410
    implicitHeight: shown ? card.implicitHeight : 0
    clip: true
    visible: shown || implicitHeight > 0
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

    Component.onCompleted: {
        shown = true
        if (!persistent)
            countdown.start()
    }

    SystemClock {
        id: ageClock
        precision: SystemClock.Minutes
    }

    NumberAnimation {
        id: countdown
        target: root
        property: "remaining"
        from: 1
        to: 0
        duration: root.timeout
        onFinished: root.shown = false
    }

    Rectangle {
        id: card
        width: parent.width
        implicitHeight: Math.max(82, content.implicitHeight + 28)
        radius: 8
        color: Colors.bgAlt
        border.width: 1
        border.color: Colors.border

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: { if (countdown.running) countdown.pause() }
            onExited: { if (countdown.running) countdown.resume() }
        }

        Column {
            id: content
            anchors.left: parent.left
            anchors.right: closeButton.left
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.rightMargin: 8
            anchors.topMargin: 14
            spacing: 4

            Row {
                width: parent.width
                spacing: 8

                Text {
                    width: Math.min(implicitWidth, Math.max(0, parent.width - age.implicitWidth - separator.implicitWidth - 16))
                    text: root.notification ? (root.notification.appName || "Notification") : ""
                    font.family: Colors.fontFamily
                    font.pixelSize: 10
                    color: Colors.fgAlt
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }

                Text {
                    id: separator
                    text: "·"
                    font.family: Colors.fontFamily
                    font.pixelSize: 10
                    color: Colors.fgAlt
                    opacity: 0.5
                }

                Text {
                    id: age
                    text: root.ageLabel
                    font.family: Colors.fontFamily
                    font.pixelSize: 10
                    color: Colors.fgAlt
                    opacity: 0.65
                }
            }

            Text {
                width: parent.width
                text: root.notification ? root.notification.summary : ""
                font.family: Colors.fontFamily
                font.pixelSize: 14
                font.bold: true
                color: Colors.fg
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text.length > 0
                text: root.notification ? root.notification.body : ""
                font.family: Colors.fontFamily
                font.pixelSize: 11
                color: Colors.fgAlt
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: closeButton
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 28
            height: 28
            radius: 7
            color: closeMouse.containsMouse ? Qt.alpha(Colors.fg, 0.08) : "transparent"

            Text {
                anchors.centerIn: parent
                text: "\ue5cd"
                font.family: Colors.iconFontFamily
                font.pixelSize: 16
                color: Colors.fgAlt
            }

            MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.shown = false
                    countdown.stop()
                    if (root.notification)
                        root.notification.dismiss()
                }
            }
        }

        // Clip the bottom progress strip to the card's rounded outline.
        Canvas {
            id: progressStrip
            anchors.fill: parent
            visible: !root.persistent
            property real progress: root.remaining
            property color trackColor: Colors.border
            property color fillColor: root.highlight
            property real cornerRadius: card.radius

            onProgressChanged: requestPaint()
            onTrackColorChanged: requestPaint()
            onFillColorChanged: requestPaint()
            onCornerRadiusChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.save()
                const r = Math.min(cornerRadius, width / 2, height / 2)
                ctx.beginPath()
                ctx.moveTo(r, 0)
                ctx.lineTo(width - r, 0)
                ctx.quadraticCurveTo(width, 0, width, r)
                ctx.lineTo(width, height - r)
                ctx.quadraticCurveTo(width, height, width - r, height)
                ctx.lineTo(r, height)
                ctx.quadraticCurveTo(0, height, 0, height - r)
                ctx.lineTo(0, r)
                ctx.quadraticCurveTo(0, 0, r, 0)
                ctx.closePath()
                ctx.clip()
                ctx.fillStyle = trackColor
                ctx.fillRect(0, height - 3, width, 3)
                ctx.fillStyle = fillColor
                ctx.fillRect(0, height - 3, width * progress, 3)
                ctx.restore()
            }
        }
    }
}
