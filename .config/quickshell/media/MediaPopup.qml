import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    property bool open: false

    property var players: Mpris.players.values.filter(p => p.trackTitle !== "" || p.playbackState !== MprisPlaybackState.Stopped)
    property int playerIndex: 0
    readonly property var player: players.length > 0 ? players[Math.min(playerIndex, players.length - 1)] : null
    readonly property bool hasPlayer: player !== null

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

    Timer {
        running: root.hasPlayer && root.player.playbackState === MprisPlaybackState.Playing
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    transformOrigin: Item.TopRight

    implicitWidth: 360
    implicitHeight: column.implicitHeight + 32

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

    readonly property int barCount: 24
    property var bars: Array(barCount).fill(0)

    Process {
        id: cavaProc
        running: root.open && root.hasPlayer && root.player.isPlaying
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/quickshell/media/cava.conf"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const parts = line.split(";").filter(v => v !== "")
                if (parts.length !== root.barCount)
                    return
                root.bars = parts.map(v => Math.max(0, Math.min(100, parseInt(v, 10) || 0)))
            }
        }
        onRunningChanged: {
            if (!running)
                root.bars = Array(root.barCount).fill(0)
        }
    }

    function fmtTime(seconds) {
        if (!seconds || seconds < 0 || !isFinite(seconds))
            return "0:00"
        const m = Math.floor(seconds / 60)
        const s = Math.floor(seconds % 60)
        return m + ":" + (s < 10 ? "0" : "") + s
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
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            visible: root.hasPlayer
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: root.hasPlayer ? (root.player.identity || "Media Player") : ""
                font.family: Colors.fontFamily
                font.pixelSize: Colors.fontSize - 3
                color: Colors.fgAlt
                elide: Text.ElideRight
            }

            Row {
                spacing: 4
                visible: root.players.length > 1

                Repeater {
                    model: root.players.length

                    delegate: Rectangle {
                        required property int index
                        width: 6
                        height: 6
                        radius: 3
                        color: index === root.playerIndex ? Colors.accent : Colors.fgAlt
                        opacity: index === root.playerIndex ? 1 : 0.4

                        Behavior on opacity {
                            NumberAnimation { duration: 120 }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -4
                            onClicked: root.playerIndex = index
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: !root.hasPlayer
            Layout.topMargin: 14
            Layout.bottomMargin: 14
            spacing: 4

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: ""
                font.family: Colors.iconFontFamily
                font.pixelSize: 26
                color: Colors.fgAlt
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "No media playing"
                font.family: Colors.fontFamily
                font.pixelSize: Colors.fontSize - 4
                color: Colors.fgAlt
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.hasPlayer
            spacing: 10

            ClippingRectangle {
                id: artFrame
                implicitWidth: 64
                implicitHeight: 64
                radius: 10
                color: Colors.bg
                border.width: 1
                border.color: Colors.border

                Image {
                    id: artImg
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: root.hasPlayer ? (root.player.trackArtUrl || "") : ""
                    asynchronous: true
                    visible: status === Image.Ready

                    Behavior on opacity {
                        NumberAnimation { duration: 200 }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: !artImg.visible
                    text: ""
                    font.family: Colors.iconFontFamily
                    font.pixelSize: 20
                    color: Colors.fgAlt
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: root.hasPlayer ? (root.player.trackTitle || "Unknown Title") : ""
                    font.family: Colors.fontFamily
                    font.pixelSize: Colors.fontSize - 1
                    font.bold: true
                    color: Colors.fg
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.hasPlayer ? (root.player.trackArtist || "Unknown Artist") : ""
                    font.family: Colors.fontFamily
                    font.pixelSize: Colors.fontSize - 3
                    color: Colors.fgAlt
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: text.length > 0
                    text: root.hasPlayer ? (root.player.trackAlbum || "") : ""
                    font.family: Colors.fontFamily
                    font.pixelSize: Colors.fontSize - 4
                    color: Colors.fgAlt
                    elide: Text.ElideRight
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            visible: root.hasPlayer

            Row {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: parent.height
                spacing: 3

                Repeater {
                    model: root.barCount

                    delegate: Rectangle {
                        required property int index

                        width: (parent.width - (root.barCount - 1) * 3) / root.barCount
                        height: Math.max(2, parent.height * (root.bars[index] / 100))
                        anchors.bottom: parent.bottom
                        radius: 1.5
                        color: root.hasPlayer && root.player.isPlaying ? Colors.fg : Colors.fgAlt

                        Behavior on height {
                            NumberAnimation { duration: 90; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.hasPlayer
            spacing: 4

            Rectangle {
                id: progressTrack
                Layout.fillWidth: true
                implicitHeight: 5
                radius: 3
                color: Colors.bg
                border.width: 1
                border.color: Colors.border

                readonly property real ratio: (root.hasPlayer && root.player.length > 0)
                    ? Math.max(0, Math.min(1, root.player.position / root.player.length))
                    : 0

                Rectangle {
                    width: parent.width * parent.ratio
                    height: parent.height
                    radius: 3
                    color: Colors.accent

                    Behavior on width {
                        NumberAnimation { duration: 200 }
                    }
                }

                Rectangle {
                    visible: root.hasPlayer && root.player.canSeek && root.player.positionSupported
                    width: 10
                    height: 10
                    radius: 5
                    color: Colors.fg
                    border.width: 1
                    border.color: Colors.accent
                    y: (parent.height - height) / 2
                    x: Math.max(0, Math.min(parent.width - width, parent.width * parent.ratio - width / 2))

                    Behavior on x {
                        NumberAnimation { duration: 200 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    enabled: root.hasPlayer && root.player.canSeek && root.player.positionSupported
                    onPressed: mouse => seekTo(mouse.x)
                    onPositionChanged: mouse => {
                        if (pressed)
                            seekTo(mouse.x)
                    }
                    function seekTo(x) {
                        const r = Math.max(0, Math.min(1, x / progressTrack.width))
                        root.player.position = r * root.player.length
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: root.hasPlayer ? root.fmtTime(root.player.position) : "0:00"
                    font.family: Colors.fontFamily
                    font.pixelSize: Colors.fontSize - 5
                    color: Colors.fgAlt
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.hasPlayer ? root.fmtTime(root.player.length) : "0:00"
                    font.family: Colors.fontFamily
                    font.pixelSize: Colors.fontSize - 5
                    color: Colors.fgAlt
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            visible: root.hasPlayer
            spacing: 4

            MediaIconBtn {
                glyph: ""
                active: root.hasPlayer && root.player.shuffleSupported && root.player.shuffle
                enabled: root.hasPlayer && root.player.canControl && root.player.shuffleSupported
                small: true
                onClicked: root.player.shuffle = !root.player.shuffle
            }

            Item { Layout.fillWidth: true }

            MediaIconBtn {
                glyph: ""
                enabled: root.hasPlayer && root.player.canGoPrevious
                onClicked: root.player.previous()
            }

            MediaIconBtn {
                id: playBtn
                primary: true
                glyph: (root.hasPlayer && root.player.isPlaying) ? "" : ""
                enabled: root.hasPlayer && root.player.canTogglePlaying
                onClicked: root.player.togglePlaying()
            }

            MediaIconBtn {
                glyph: ""
                enabled: root.hasPlayer && root.player.canGoNext
                onClicked: root.player.next()
            }

            Item { Layout.fillWidth: true }

            MediaIconBtn {
                id: loopBtn
                glyph: {
                    if (!root.hasPlayer)
                        return ""
                    return root.player.loopState === MprisLoopState.Track ? "" : ""
                }
                active: root.hasPlayer && root.player.loopSupported && root.player.loopState !== MprisLoopState.None
                enabled: root.hasPlayer && root.player.canControl && root.player.loopSupported
                small: true
                onClicked: {
                    const s = root.player.loopState
                    if (s === MprisLoopState.None)
                        root.player.loopState = MprisLoopState.Playlist
                    else if (s === MprisLoopState.Playlist)
                        root.player.loopState = MprisLoopState.Track
                    else
                        root.player.loopState = MprisLoopState.None
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.hasPlayer && root.player.volumeSupported
            spacing: 8

            Text {
                text: ""
                font.family: Colors.iconFontFamily
                font.pixelSize: Colors.fontSize - 2
                color: Colors.fgAlt
            }

            Rectangle {
                id: volTrack
                Layout.fillWidth: true
                implicitHeight: 4
                radius: 2
                color: Colors.bg
                border.width: 1
                border.color: Colors.border

                Rectangle {
                    width: parent.width * (root.hasPlayer ? root.player.volume : 0)
                    height: parent.height
                    radius: 2
                    color: Colors.secondary

                    Behavior on width {
                        NumberAnimation { duration: 120 }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    enabled: root.hasPlayer && root.player.canControl
                    onPressed: mouse => setVol(mouse.x)
                    onPositionChanged: mouse => {
                        if (pressed)
                            setVol(mouse.x)
                    }
                    function setVol(x) {
                        root.player.volume = Math.max(0, Math.min(1, x / volTrack.width))
                    }
                }
            }
        }
    }
}
