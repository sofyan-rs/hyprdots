import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    required property var controller
    screen: controller.barScreen
    visible: controller.open && controller.powerOpen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true; bottom: true; left: true }
    WlrLayershell.namespace: "quickshell-controlcenter-modal"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    onVisibleChanged: {
        card.pendingAction = null
        if (visible) Qt.callLater(() => card.forceActiveFocus())
    }
    Rectangle { anchors.fill: parent; color: "#99000000" }
    MouseArea { anchors.fill: parent; onClicked: card.cancel() }
    PowerCard {
        id: card
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width - 40)
        controller: root.controller
    }
}
