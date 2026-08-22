import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root

    required property var barScreen

    screen: barScreen
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    margins.top: Colors.barHeight
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: PopupManager.activeId !== "" && PopupManager.activeScreen === barScreen
    WlrLayershell.namespace: "quickshell-catcher"

    MouseArea {
        anchors.fill: parent
        onClicked: PopupManager.close()
    }
}
