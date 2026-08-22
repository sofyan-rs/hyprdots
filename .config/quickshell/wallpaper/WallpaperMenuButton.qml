import Quickshell
import Quickshell.Wayland
import QtQuick
import "../core"

Pill {
    id: root

    required property var barScreen

    readonly property bool open: PopupManager.activeId === "wallpapermenu" && PopupManager.activeScreen === barScreen

    implicitWidth: label.implicitWidth + 20

    Text {
        id: label
        anchors.centerIn: parent
        text: "\ue1bc"
        font.family: Colors.iconFontFamily
        font.pixelSize: Colors.fontSize
        color: Colors.wallpaperIcon
    }

    MouseArea {
        anchors.fill: parent
        onClicked: PopupManager.toggle("wallpapermenu", root.barScreen)
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

        WallpaperMenuPopup {
            id: content
            barScreen: root.barScreen
            open: root.open
        }
    }
}
