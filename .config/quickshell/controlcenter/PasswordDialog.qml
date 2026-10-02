import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import "../core"

PanelWindow {
    id: root
    required property var controller
    signal submitted(string password, bool autojoin)
    signal cancelled()
    property bool reveal: false
    property bool autojoin: true
    screen: controller.barScreen
    visible: controller.open && controller.pendingNetwork !== null
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true; bottom: true; left: true }
    WlrLayershell.namespace: "quickshell-controlcenter-modal"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    onVisibleChanged: {
        password.text = ""
        reveal = false
        autojoin = true
        if (visible) Qt.callLater(() => password.forceActiveFocus())
    }
    Rectangle { anchors.fill: parent; color: "#99000000" }
    MouseArea { anchors.fill: parent; enabled: !root.controller.network.busy; onClicked: root.cancelled() }
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(440, parent.width - 40)
        height: form.implicitHeight + 44
        radius: 18; color: Colors.bgAlt; border.width: 1; border.color: Colors.border
        MouseArea { anchors.fill: parent; onClicked: password.forceActiveFocus() }
        ColumnLayout {
            id: form
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 22; spacing: 14
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                Rectangle {
                    Layout.preferredWidth: 40; Layout.preferredHeight: 40; radius: 11; color: Colors.fg
                    Text { anchors.centerIn: parent; text: "\ue63e"; font.family: Colors.iconFontFamily; font.pixelSize: 23; color: Colors.bg }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 5
                    CcText { Layout.fillWidth: true; text: "Connect to " + (root.controller.pendingNetwork ? root.controller.pendingNetwork.ssid : "Wi-Fi"); font.pixelSize: 16; font.bold: true }
                    CcText { text: "Secured network"; font.pixelSize: 11; color: Colors.fgAlt }
                }
                CcButton { icon: "\ue5cd"; implicitWidth: 28; implicitHeight: 28; color: "transparent"; enabled: !root.controller.network.busy; onClicked: root.cancelled() }
            }
            CcText { text: "Password"; font.pixelSize: 12 }
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 46; radius: 10
                color: Colors.surfaceAlt; border.width: 1; border.color: password.activeFocus ? Colors.fgAlt : Colors.border
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 8; spacing: 8
                    TextInput {
                        id: password
                        Layout.fillWidth: true; clip: true; selectByMouse: true
                        color: Colors.fg; font.family: Colors.fontFamily; font.pixelSize: 14
                        enabled: !root.controller.network.busy
                        echoMode: root.reveal ? TextInput.Normal : TextInput.Password
                        inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                        Keys.onReturnPressed: root.submit()
                        Keys.onEscapePressed: { if (!root.controller.network.busy) root.cancelled() }
                    }
                    CcButton { icon: root.reveal ? "\ue8f5" : "\ue8f4"; implicitWidth: 28; implicitHeight: 28; color: "transparent"; onClicked: root.reveal = !root.reveal }
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                CcSwitch { checked: root.autojoin; enabled: !root.controller.network.busy; onClicked: root.autojoin = !root.autojoin }
                CcText { text: "Connect automatically"; font.pixelSize: 11 }
                Item { Layout.fillWidth: true }
                CcText { text: "Saved on this device"; font.pixelSize: 9; color: Colors.fgAlt }
            }
            CcText { Layout.fillWidth: true; visible: root.controller.network.error !== ""; text: root.controller.network.error; wrapMode: Text.Wrap; maximumLineCount: 4; color: Colors.accent; font.pixelSize: 11 }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                CcButton { Layout.fillWidth: true; Layout.preferredWidth: 0; Layout.minimumWidth: 0; text: "Cancel"; enabled: !root.controller.network.busy; onClicked: root.cancelled() }
                CcButton { Layout.fillWidth: true; Layout.preferredWidth: 0; Layout.minimumWidth: 0; text: root.controller.network.busy ? "Connecting…" : "Connect"; primary: true; enabled: password.text.length > 0 && !root.controller.network.busy; onClicked: root.submit() }
            }
        }
    }
    function submit() {
        if (password.text.length === 0 || controller.network.busy) return
        submitted(password.text, autojoin)
        password.text = ""
    }
}
