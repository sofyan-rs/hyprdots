import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick
import "../core"

Pill {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    required property var barScreen

    readonly property bool open: PopupManager.activeId === "volume" && PopupManager.activeScreen === barScreen

    bgColor: muted ? Colors.secondary : Colors.bgAlt
    implicitWidth: row.implicitWidth + 20

    PwObjectTracker {
        objects: [root.sink]
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.muted ? "\ue04f" : (root.volume <= 0.5 ? "\ue04d" : "\ue050")
            font.family: Colors.iconFontFamily
            font.pixelSize: Colors.fontSize + 2
            color: root.muted ? Colors.accentText : Colors.fg
        }

        Text {
            text: Math.round(root.volume * 100) + "%"
            font.family: Colors.fontFamily
            font.pixelSize: Colors.fontSize
            font.bold: true
            color: root.muted ? Colors.accentText : Colors.fg
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                proc.running = true
                return
            }
            PopupManager.toggle("volume", root.barScreen)
        }
    }

    Process {
        id: proc
        command: ["pavucontrol"]
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

        VolumePopup {
            id: content
            open: root.open
        }
    }
}
