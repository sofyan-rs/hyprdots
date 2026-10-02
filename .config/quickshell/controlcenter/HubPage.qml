import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import Quickshell.Widgets
import "../core"
import "../notifications"

ColumnLayout {
    id: root
    required property var controller
    spacing: 12
    RowLayout {
        Layout.fillWidth: true; spacing: 10
        Repeater {
            model: ["wifi", "bluetooth"]
            delegate: Rectangle {
                required property string modelData
                readonly property bool wifiTile: modelData === "wifi"
                readonly property bool active: wifiTile ? root.controller.network.state.enabled : root.controller.bluetoothOn
                Layout.fillWidth: true; Layout.preferredHeight: tileContent.implicitHeight + 28
                radius: 14
                color: active && wifiTile ? Colors.fg : Colors.surfaceAlt
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.controller.tab = modelData; root.controller.page = "connections" } }
                ColumnLayout {
                    id: tileContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    spacing: 4
                    Text { text: wifiTile ? "\ue63e" : "\ue1a7"; font.family: Colors.iconFontFamily; font.pixelSize: 20; color: active && wifiTile ? Colors.bg : Colors.accent }
                    CcText { text: wifiTile ? "Wi-Fi" : "Bluetooth"; font.bold: true; color: active && wifiTile ? Colors.bg : Colors.fg }
                    CcText { Layout.fillWidth: true; text: wifiTile ? (root.controller.wifi ? root.controller.wifi.ssid : (active ? "Not connected" : "Off")) : (active ? "On · " + root.controller.connectedDevices.length + " devices" : "Off"); font.pixelSize: 10; color: active && wifiTile ? Qt.alpha(Colors.bg, 0.65) : Colors.fgAlt }
                }
                Text { anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 14; text: "\ue5cc"; font.family: Colors.iconFontFamily; font.pixelSize: 18; color: active && wifiTile ? Colors.bg : Colors.fgAlt }
            }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true; spacing: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: "\ue050"; font.family: Colors.iconFontFamily; font.pixelSize: 21; color: Colors.accent }
            CcText { text: "Volume" }
            Item { Layout.fillWidth: true }
            CcText { text: Math.round(root.controller.volume * 100) + "%"; color: Colors.fgAlt; font.pixelSize: 12 }
            CcButton { text: root.controller.muted ? "Unmute" : "Mute"; icon: "\ue04f"; implicitHeight: 28; enabled: root.controller.sink !== null; onClicked: root.controller.toggleMute() }
        }
        Slider {
            id: volumeSlider
            Layout.fillWidth: true; Layout.preferredHeight: 22
            padding: 0
            from: 0; to: 1
            enabled: root.controller.sink !== null
            value: root.controller.volume
            onMoved: root.controller.setVolume(value)
            background: Rectangle {
                x: volumeSlider.leftPadding; y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
                width: volumeSlider.availableWidth; height: 7; radius: 3.5; color: Colors.border
                Rectangle { width: parent.width * volumeSlider.visualPosition; height: parent.height; radius: 3.5; color: Colors.accent }
            }
            handle: Rectangle {
                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
                width: 18; height: 18; radius: 9; color: Colors.fg; border.width: 2; border.color: Colors.accent
            }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: mediaColumn.implicitHeight + 28
        radius: 14; color: Colors.surface
        ColumnLayout {
            id: mediaColumn
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 14; spacing: 8
            RowLayout {
                Layout.fillWidth: true
                CcText { text: "NOW PLAYING"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1; color: Colors.accent }
                Item { Layout.fillWidth: true }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                ClippingRectangle {
                    Layout.preferredWidth: 48; Layout.preferredHeight: 48; radius: 10
                    color: Colors.fg
                    Image {
                        id: coverArt
                        anchors.fill: parent
                        source: root.controller.player ? (root.controller.player.trackArtUrl || "") : ""
                        asynchronous: true
                        sourceSize.width: 96
                        sourceSize.height: 96
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }
                    Text { anchors.centerIn: parent; visible: coverArt.status !== Image.Ready; text: "\ue405"; font.family: Colors.iconFontFamily; font.pixelSize: 26; color: Colors.bg }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 4
                    CcText { Layout.fillWidth: true; text: root.controller.player ? (root.controller.player.trackTitle || "Unknown track") : "Nothing playing"; font.pixelSize: 13 }
                    CcText { Layout.fillWidth: true; text: root.controller.player ? [root.controller.player.trackArtist, root.controller.player.identity].filter(s => s).join(" · ") : "Play something to see it here"; font.pixelSize: 11; color: Colors.fgAlt }
                }
                CcButton { icon: root.controller.player && root.controller.player.isPlaying ? "\ue034" : "\ue037"; primary: true; color: Colors.accent; implicitWidth: 38; implicitHeight: 38; radius: 19; enabled: root.controller.player && root.controller.player.canTogglePlaying; onClicked: root.controller.player.togglePlaying() }
            }
            Rectangle {
                id: progress
                Layout.fillWidth: true; Layout.preferredHeight: 4; radius: 2; color: Colors.border
                readonly property real ratio: root.controller.player && root.controller.player.length > 0 ? Math.max(0, Math.min(1, root.controller.player.position / root.controller.player.length)) : 0
                Rectangle { height: parent.height; width: parent.width * parent.ratio; radius: 2; color: Colors.accent }
                MouseArea {
                    anchors.fill: parent; anchors.margins: -5
                    enabled: root.controller.player && root.controller.player.canSeek && root.controller.player.positionSupported
                    onClicked: mouse => root.controller.player.position = Math.max(0, Math.min(1, mouse.x / progress.width)) * root.controller.player.length
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 0
                CcText { Layout.preferredWidth: 48; text: root.controller.formatTime(root.controller.player ? root.controller.player.position : 0); font.pixelSize: 10; color: Colors.fgAlt }
                Item { Layout.fillWidth: true }
                RowLayout {
                    spacing: 8
                    CcButton { icon: "\ue045"; implicitWidth: 24; implicitHeight: 24; color: "transparent"; enabled: root.controller.player && root.controller.player.canGoPrevious; onClicked: root.controller.player.previous() }
                    CcButton { icon: "\ue044"; implicitWidth: 24; implicitHeight: 24; color: "transparent"; enabled: root.controller.player && root.controller.player.canGoNext; onClicked: root.controller.player.next() }
                }
                Item { Layout.fillWidth: true }
                CcText { Layout.preferredWidth: 48; horizontalAlignment: Text.AlignRight; text: root.controller.formatTime(root.controller.player ? root.controller.player.length : 0); font.pixelSize: 10; color: Colors.fgAlt }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        CcText { text: "Notifications"; font.bold: true; font.pixelSize: 15 }
        Item { Layout.fillWidth: true }
        CcButton { text: "Clear all"; color: "transparent"; danger: true; implicitHeight: 22; enabled: NotificationHub.notifications.values.length > 0; onClicked: NotificationHub.dismissAll() }
    }
    ColumnLayout {
        Layout.fillWidth: true; spacing: 8
        CcText { visible: NotificationHub.notifications.values.length === 0; text: "You're all caught up"; color: Colors.fgAlt; font.pixelSize: 12; Layout.bottomMargin: 0 }
        Repeater {
            model: NotificationHub.notifications.values
            delegate: Rectangle {
                id: notificationRow
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: notificationColumn.implicitHeight + 22
                radius: 12; color: Colors.surface
                ColumnLayout {
                    id: notificationColumn
                    anchors.left: parent.left; anchors.right: close.left; anchors.top: parent.top
                    anchors.leftMargin: 12; anchors.rightMargin: 8; anchors.topMargin: 11; spacing: 4
                    CcText { Layout.fillWidth: true; text: notificationRow.modelData.appName || "Notification"; font.pixelSize: 10; color: Colors.fgAlt }
                    CcText { Layout.fillWidth: true; text: notificationRow.modelData.summary + (notificationRow.modelData.body ? " · " + notificationRow.modelData.body.replace(/<[^>]*>/g, "") : ""); font.pixelSize: 12; maximumLineCount: 2; wrapMode: Text.Wrap }
                }
                CcButton { id: close; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: 8; icon: "\ue5cd"; implicitWidth: 28; implicitHeight: 28; color: "transparent"; onClicked: notificationRow.modelData.dismiss() }
            }
        }
    }
}
