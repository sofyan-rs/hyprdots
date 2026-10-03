import Quickshell
import Quickshell.Wayland
import QtQuick

PanelWindow {
    id: root
    required property var controller
    screen: controller.barScreen
    // Item.visible includes ancestor visibility. Using modal.visible here
    // makes a hidden window wait for its own child to become visible.
    visible: modal.opened || modal.opacity > 0
    onVisibleChanged: if (visible) Qt.callLater(() => modal.focusCard())
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true; bottom: true; left: true }
    WlrLayershell.namespace: "quickshell-controlcenter-modal"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    PowerModal {
        id: modal
        anchors.fill: parent
        controller: root.controller
        opened: controller.open && controller.powerOpen
    }
}
