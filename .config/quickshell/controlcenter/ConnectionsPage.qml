import QtQuick
import QtQuick.Layouts
import "../core"

ColumnLayout {
    id: root
    required property var controller
    readonly property bool wifiTab: controller.tab === "wifi"
    property string expandedDevice: ""
    spacing: 14

    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 42
        radius: 12; color: Colors.surfaceAlt
        RowLayout {
            anchors.fill: parent; anchors.margins: 3; spacing: 3
            Repeater {
                model: ["wifi", "bluetooth"]
                delegate: CcButton {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 0
                    Layout.minimumWidth: 0
                    text: modelData === "wifi" ? "Wi-Fi" : "Bluetooth"
                    icon: modelData === "wifi" ? "\ue63e" : "\ue1a7"
                    primary: root.controller.tab === modelData
                    color: primary ? Colors.fg : "transparent"
                    onClicked: root.controller.tab = modelData
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 62
        radius: 14; color: Colors.surfaceAlt
        RowLayout {
            anchors.fill: parent; anchors.margins: 12; spacing: 12
            Rectangle {
                Layout.preferredWidth: 38; Layout.preferredHeight: 38; radius: 10; color: Colors.fg
                Text { anchors.centerIn: parent; text: root.wifiTab ? "\ue63e" : "\ue1a7"; font.family: Colors.iconFontFamily; font.pixelSize: 23; color: Colors.bg }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                CcText { Layout.fillWidth: true; font.bold: true; text: root.wifiTab ? (root.controller.wifi ? root.controller.wifi.ssid : (root.controller.network.state.enabled ? "Wi-Fi is on" : "Wi-Fi is off")) : (root.controller.bluetoothOn ? "Bluetooth is on" : "Bluetooth is off") }
                CcText { Layout.fillWidth: true; font.pixelSize: 11; color: Colors.fgAlt; text: root.wifiTab ? (root.controller.wifi ? "Connected · " + (root.controller.wifi.secured ? "Secured" : "Open network") : "Choose a network below") : (root.controller.adapter ? (root.controller.adapter.discoverable ? "Visible to nearby devices" : "Ready to connect") : "No Bluetooth adapter found") }
            }
            CcSwitch {
                checked: root.wifiTab ? root.controller.network.state.enabled : root.controller.bluetoothOn
                enabled: root.wifiTab ? !root.controller.network.busy : root.controller.adapter !== null
                onClicked: {
                    if (root.wifiTab) root.controller.network.run({ action: "radio", enabled: !checked })
                    else root.controller.adapter.enabled = !checked
                }
            }
        }
    }

    StackLayout {
        id: tabContent
        Layout.fillWidth: true
        Layout.fillHeight: false
        currentIndex: root.wifiTab ? 0 : 1
        implicitHeight: root.wifiTab ? wifiPane.implicitHeight : bluetoothPane.implicitHeight
        Layout.preferredHeight: implicitHeight

        ColumnLayout {
            id: wifiPane
            opacity: root.wifiTab ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Layout.fillWidth: true; Layout.fillHeight: false; spacing: 8
            RowLayout {
                Layout.fillWidth: true
                CcText { text: "AVAILABLE NETWORKS"; font.pixelSize: 10; color: Colors.accent }
                Item { Layout.fillWidth: true }
                CcButton { text: root.controller.network.scanning ? "Scanning…" : "Refresh"; horizontalPadding: 0; color: "transparent"; danger: true; implicitHeight: contentHeight; enabled: root.controller.network.state.enabled && !root.controller.network.busy; onClicked: root.controller.network.run({ action: "scan" }) }
            }
            Repeater {
                model: root.controller.network.state.enabled ? root.controller.network.state.networks.filter(n => !n.inUse) : []
                delegate: CcRow {
                    required property var modelData
                    Layout.fillWidth: true
                    title: modelData.ssid
                    icon: "\ue63e"
                    subtitle: (modelData.signal >= 66 ? "Strong signal" : (modelData.signal >= 33 ? "Moderate signal" : "Weak signal")) + " · " + (modelData.secured ? "Secured" : "Open network")
                    enabled: !root.controller.network.busy
                    onClicked: root.controller.connectNetwork(modelData)
                }
            }
            CcEmptyState { Layout.fillWidth: true; visible: !root.controller.network.state.enabled || root.controller.network.state.networks.filter(n => !n.inUse).length === 0; text: root.controller.network.state.enabled ? "No nearby networks. Try Refresh." : "Enable Wi-Fi to find networks" }
            CcRow { Layout.fillWidth: true; title: "Manage saved networks"; icon: "\ue429"; iconColor: Colors.accent; onClicked: root.controller.page = "saved" }
        }

        ColumnLayout {
            id: bluetoothPane
            opacity: root.wifiTab ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            Layout.fillWidth: true; Layout.fillHeight: false; spacing: 8
            RowLayout {
                Layout.fillWidth: true
                CcText { text: "CONNECTED DEVICES"; font.pixelSize: 10; color: Colors.accent }
                Item { Layout.fillWidth: true }
                CcText { text: root.controller.connectedDevices.length + " devices"; font.pixelSize: 11; color: Colors.fgAlt }
            }
            Repeater {
                model: root.controller.connectedDevices
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true; spacing: 6
                    CcRow {
                        Layout.fillWidth: true
                        title: modelData.name || modelData.address
                        subtitle: "Connected"
                        icon: root.deviceIcon(modelData.icon)
                        trailing: "\ue5d3"
                        onClicked: root.expandedDevice = root.expandedDevice === modelData.address ? "" : modelData.address
                    }
                    RowLayout {
                        visible: root.expandedDevice === modelData.address
                        Layout.fillWidth: true
                        CcButton { text: "Disconnect"; Layout.fillWidth: true; onClicked: modelData.connected = false }
                        CcButton { text: "Forget device"; danger: true; Layout.fillWidth: true; onClicked: modelData.forget() }
                    }
                }
            }
            CcEmptyState { Layout.fillWidth: true; visible: root.controller.connectedDevices.length === 0; text: "No connected devices" }
            RowLayout {
                Layout.fillWidth: true; Layout.topMargin: 8
                CcText { text: "NEARBY DEVICES"; font.pixelSize: 10; color: Colors.accent }
                Item { Layout.fillWidth: true }
                CcButton { text: root.controller.adapter && root.controller.adapter.discovering ? "Scanning" : "Scan"; icon: "\ue5d5"; horizontalPadding: 0; color: "transparent"; danger: true; implicitHeight: contentHeight; enabled: root.controller.bluetoothOn; onClicked: root.controller.scanBluetooth() }
            }
            Repeater {
                model: root.controller.bluetoothOn ? root.controller.nearbyDevices : []
                delegate: CcRow {
                    required property var modelData
                    Layout.fillWidth: true
                    title: modelData.name || modelData.address
                    subtitle: modelData.pairing ? "Pairing…" : (modelData.paired ? "Paired · Click to connect" : "Available to pair")
                    icon: root.deviceIcon(modelData.icon)
                    enabled: !modelData.pairing
                    onClicked: root.controller.connectDevice(modelData)
                }
            }
            CcEmptyState { Layout.fillWidth: true; visible: !root.controller.bluetoothOn || root.controller.nearbyDevices.length === 0; text: root.controller.bluetoothOn ? "No nearby devices found" : "Enable Bluetooth to discover devices" }
            CcText { Layout.fillWidth: true; visible: root.controller.bluetoothMessage !== ""; text: root.controller.bluetoothMessage; color: Colors.accent; font.pixelSize: 11; wrapMode: Text.Wrap }
        }

    }

    function deviceIcon(icon) {
        if (icon.includes("head") || icon.includes("audio")) return "\ue310"
        if (icon.includes("mouse")) return "\ue323"
        if (icon.includes("keyboard")) return "\ue312"
        if (icon.includes("phone")) return "\ue324"
        return "\ue1a7"
    }
}
