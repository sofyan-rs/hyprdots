import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import QtQuick
import "../core"

Pill {
    id: root

    required property var barScreen

    readonly property bool open: PopupManager.activeId === "media" && PopupManager.activeScreen === barScreen

    property var players: Mpris.players.values.filter(p => p.trackTitle !== "" || p.playbackState !== MprisPlaybackState.Stopped)
    property int playerIndex: 0
    readonly property var player: players.length > 0 ? players[Math.min(playerIndex, players.length - 1)] : null
    readonly property bool hasPlayer: player !== null
    readonly property bool playing: hasPlayer && player.isPlaying

    function pickBestPlayer() {
        for (let i = 0; i < players.length; i++) {
            if (players[i].isPlaying) {
                playerIndex = i
                return
            }
        }
        if (playerIndex >= players.length)
            playerIndex = 0
    }

    onPlayersChanged: pickBestPlayer()
    Component.onCompleted: pickBestPlayer()

    implicitWidth: row.implicitWidth + 20

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.hasPlayer ? (root.playing ? "" : "") : ""
            font.family: Colors.iconFontFamily
            font.pixelSize: Colors.fontSize
            color: root.hasPlayer ? Colors.accent : Colors.fgAlt
        }

        Item {
            id: marqueeClip
            anchors.verticalCenter: parent.verticalCenter
            visible: root.hasPlayer
            clip: true
            implicitWidth: Math.min(titleText.implicitWidth, 190)
            implicitHeight: titleText.implicitHeight

            readonly property real overflow: Math.max(0, titleText.implicitWidth - width)

            Text {
                id: titleText
                text: root.hasPlayer ? (root.player.trackTitle || "") : ""
                onTextChanged: x = 0
                font.family: Colors.fontFamily
                font.pixelSize: Colors.fontSize
                color: Colors.fg

                SequentialAnimation on x {
                    running: marqueeClip.overflow > 0
                    loops: Animation.Infinite

                    PauseAnimation { duration: 1200 }
                    NumberAnimation {
                        from: 0
                        to: -marqueeClip.overflow
                        duration: Math.max(1200, marqueeClip.overflow * 40)
                        easing.type: Easing.Linear
                    }
                    PauseAnimation { duration: 1200 }
                    NumberAnimation {
                        from: -marqueeClip.overflow
                        to: 0
                        duration: Math.max(1200, marqueeClip.overflow * 40)
                        easing.type: Easing.Linear
                    }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: PopupManager.toggle("media", root.barScreen)
    }

    function updatePopupPosition() {
        const screenW = root.barScreen ? root.barScreen.width : 0
        const pos = root.mapToItem(null, root.width, 0)
        popup.rightMargin = Math.max(4, screenW - pos.x)
    }

    onOpenChanged: {
        if (open)
            Qt.callLater(updatePopupPosition)
    }

    PanelWindow {
        id: popup

        property real rightMargin: 20

        screen: root.barScreen
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-popup"
        WlrLayershell.layer: WlrLayer.Overlay

        anchors {
            top: true
            right: true
        }
        margins.top: Colors.barHeight + 2
        margins.right: rightMargin

        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight

        MediaPopup {
            id: content
            open: root.open
        }
    }
}
