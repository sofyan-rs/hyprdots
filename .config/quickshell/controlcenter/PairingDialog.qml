import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../core"

PanelWindow {
    id: root
    required property var controller
    screen: controller.barScreen
    visible: controller.open && controller.pairingPrompt !== ""
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true; bottom: true; left: true }
    WlrLayershell.namespace: "quickshell-controlcenter-modal"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    onVisibleChanged: { pin.text = ""; if (visible && !controller.pairingConfirmation) Qt.callLater(() => pin.forceActiveFocus()) }
    Rectangle { anchors.fill: parent; color: "#99000000" }
    Rectangle {
        anchors.centerIn: parent; width: Math.min(420, parent.width - 40); height: form.implicitHeight + 40
        radius: 18; color: Colors.bgAlt; border.width: 1; border.color: Colors.border
        ColumnLayout {
            id: form
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 20; spacing: 14
            CcText { text: "Pair Bluetooth device"; font.pixelSize: 18; font.bold: true }
            CcText { Layout.fillWidth: true; text: root.controller.pairingPrompt; wrapMode: Text.Wrap; color: Colors.fgAlt }
            Rectangle {
                visible: !root.controller.pairingConfirmation
                Layout.fillWidth: true; Layout.preferredHeight: 42; radius: 8; color: Colors.border
                TextInput { id: pin; anchors.fill: parent; anchors.margins: 10; color: Colors.fg; font.family: Colors.fontFamily; font.pixelSize: 14; clip: true; Keys.onReturnPressed: { if (text.length > 0) root.controller.answerPairing(text) } }
            }
            RowLayout {
                Layout.fillWidth: true
                CcButton { Layout.fillWidth: true; Layout.preferredWidth: 0; Layout.minimumWidth: 0; text: "Cancel"; onClicked: { root.controller.answerPairing("no"); if (root.controller.pairingDevice) root.controller.pairingDevice.cancelPair() } }
                CcButton { Layout.fillWidth: true; Layout.preferredWidth: 0; Layout.minimumWidth: 0; primary: true; text: root.controller.pairingConfirmation ? "Confirm" : "Pair"; enabled: root.controller.pairingConfirmation || pin.text.length > 0; onClicked: root.controller.answerPairing(root.controller.pairingConfirmation ? "yes" : pin.text) }
            }
        }
    }
}
