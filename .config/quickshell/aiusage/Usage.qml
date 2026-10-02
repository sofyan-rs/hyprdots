import Quickshell
import Quickshell.Wayland
import QtQuick
import "../core"

Pill {
    id: root
    required property var barScreen
    readonly property bool open: PopupManager.activeId === "aiusage" && PopupManager.activeScreen === barScreen
    flat: true
    implicitWidth: 26

    Text {
        anchors.centerIn: parent
        text: "\uf06c"
        font.family: Colors.iconFontFamily
        font.pixelSize: 18
        color: Colors.fg
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PopupManager.toggle("aiusage", root.barScreen)
    }
    onOpenChanged: if (open) {
        const position = root.mapToItem(null, root.width, 0)
        popup.rightMargin = Math.max(4, Math.min(root.barScreen.width - popup.width - 4,
                                              root.barScreen.width - position.x))
        if (UsageState.now - UsageState.updatedAt > 60) UsageState.refresh()
    }

    PanelWindow {
        id: popup
        property real rightMargin: 20
        screen: root.barScreen
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; right: true }
        margins.top: Colors.barHeight + Colors.popupTopGap
        margins.right: rightMargin
        implicitWidth: 350
        implicitHeight: content.implicitHeight
        WlrLayershell.namespace: "quickshell-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        UsagePopup {
            id: content
            width: parent.width
            open: root.open
        }
    }
}
