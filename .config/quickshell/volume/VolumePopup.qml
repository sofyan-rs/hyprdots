import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    property bool open: false
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    transformOrigin: Item.TopRight

    implicitWidth: 240
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

    function setVolume(v) {
        if (root.sink && root.sink.audio)
            root.sink.audio.volume = Math.max(0, Math.min(1, v))
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
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: root.muted ? "\ue04f" : "\ue050"
                font.family: Colors.iconFontFamily
                font.pixelSize: 20
                color: root.muted ? Colors.fgAlt : Colors.accent

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.sink && root.sink.audio)
                            root.sink.audio.muted = !root.sink.audio.muted
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Volume"
                font.family: Colors.fontFamily
                font.pixelSize: Colors.fontSize
                font.bold: true
                color: Colors.fg
            }

            Text {
                text: Math.round(root.volume * 100) + "%"
                font.family: Colors.fontFamily
                font.pixelSize: Colors.fontSize
                font.bold: true
                color: Colors.fgAlt
            }
        }

        Item {
            id: sliderTrack
            Layout.fillWidth: true
            implicitHeight: 18

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 6
                radius: height / 2
                color: Colors.bg
                border.width: 1
                border.color: Colors.border

                Rectangle {
                    width: track.width * Math.max(0, Math.min(1, root.volume))
                    height: parent.height
                    radius: parent.radius
                    color: root.muted ? Colors.fgAlt : Colors.accent

                    Behavior on width {
                        enabled: !dragArea.pressed
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                }
            }

            Rectangle {
                id: handle
                width: 16
                height: 16
                radius: 8
                color: Colors.fg
                border.width: 2
                border.color: root.muted ? Colors.fgAlt : Colors.accent
                anchors.verticalCenter: parent.verticalCenter
                x: track.width * Math.max(0, Math.min(1, root.volume)) - width / 2
            }

            MouseArea {
                id: dragArea
                anchors.fill: parent

                property bool dragging: false

                onPressed: mouse => root.setVolume(mouse.x / width)
                onPositionChanged: mouse => {
                    if (pressed)
                        root.setVolume(mouse.x / width)
                }
            }
        }
    }
}
