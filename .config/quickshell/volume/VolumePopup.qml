import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../core"
import "../controlcenter"

Item {
    id: root

    property bool open: false
    signal interacted()
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    transformOrigin: Item.TopRight

    implicitWidth: 360
    implicitHeight: column.implicitHeight + 28

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

    function setVolume(v) {
        root.interacted()
        if (root.sink && root.sink.audio) {
            root.sink.audio.volume = Math.max(0, Math.min(1, v))
            root.sink.audio.muted = false
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Colors.bgAlt
        border.width: 1
        border.color: Colors.border
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                text: "\ue050"
                font.family: Colors.iconFontFamily
                font.pixelSize: 21
                color: Colors.accent
            }
            CcText { text: "Volume" }
            Item { Layout.fillWidth: true }
            CcText {
                text: Math.round(root.volume * 100) + "%"
                font.pixelSize: 12
                color: Colors.fgAlt
            }
            CcButton {
                text: root.muted ? "Unmute" : "Mute"
                icon: "\ue04f"
                implicitHeight: 28
                enabled: root.sink !== null
                onClicked: {
                    root.interacted()
                    if (root.sink && root.sink.audio)
                        root.sink.audio.muted = !root.sink.audio.muted
                }
            }
        }

        Slider {
            id: volumeSlider
            Layout.fillWidth: true
            Layout.preferredHeight: 22
            padding: 0
            from: 0
            to: 1
            enabled: root.sink !== null
            value: root.volume
            onMoved: root.setVolume(value)
            background: Rectangle {
                x: volumeSlider.leftPadding
                y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
                width: volumeSlider.availableWidth
                height: 7
                radius: 3.5
                color: Colors.border
                Rectangle {
                    width: parent.width * volumeSlider.visualPosition
                    height: parent.height
                    radius: 3.5
                    color: Colors.accent
                }
            }
            handle: Rectangle {
                x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                y: volumeSlider.topPadding + (volumeSlider.availableHeight - height) / 2
                width: 18
                height: 18
                radius: 9
                color: Colors.fg
                border.width: 2
                border.color: Colors.accent
            }
        }
    }
}
