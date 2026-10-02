import QtQuick
import QtQuick.Layouts
import "../core"

ColumnLayout {
    id: root
    required property var controller
    property string query: ""
    property string expandedUuid: ""
    readonly property var filtered: controller.network.state.saved.filter(n => (n.ssid || n.name).toLowerCase().includes(query.toLowerCase()))
    spacing: 12
    Component.onCompleted: {
        const current = controller.network.state.saved.find(n => n.connected)
        expandedUuid = current ? current.uuid : ""
    }

    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 40; radius: 10; color: Colors.surface
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
            Text { text: "\ue8b6"; font.family: Colors.iconFontFamily; font.pixelSize: 19; color: Colors.fgAlt }
            TextInput {
                id: savedSearch
                Layout.fillWidth: true; color: Colors.fg; font.family: Colors.fontFamily; font.pixelSize: 12; clip: true; selectByMouse: true
                onTextChanged: root.query = text
                Text { visible: savedSearch.text.length === 0; text: "Search saved networks…"; font.family: Colors.fontFamily; font.pixelSize: 12; color: Colors.fgAlt }
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        CcText { text: "SAVED NETWORKS"; font.pixelSize: 10; color: Colors.accent }
        Item { Layout.fillWidth: true }
        CcText { text: root.filtered.length + " networks"; font.pixelSize: 11; color: Colors.fgAlt }
    }
    Repeater {
        model: root.filtered
        delegate: Rectangle {
            id: savedCard
            required property var modelData
            readonly property bool expanded: root.expandedUuid === modelData.uuid
            Layout.fillWidth: true
            implicitHeight: expanded ? 116 : 56
            radius: 12; color: Colors.surface
            ColumnLayout {
                anchors.fill: parent; spacing: 6
                CcRow {
                    Layout.fillWidth: true; Layout.preferredHeight: 56
                    color: "transparent"
                    title: savedCard.modelData.ssid || savedCard.modelData.name
                    subtitle: savedCard.modelData.connected ? "Connected · " + (savedCard.modelData.secured ? "Secured" : "Open network") : "Saved · Auto-join " + (savedCard.modelData.autojoin ? "on" : "off")
                    icon: "\ue63e"; highlighted: savedCard.modelData.connected
                    trailing: savedCard.modelData.connected ? "\ue5ca" : "\ue5cc"
                    onClicked: root.expandedUuid = savedCard.expanded ? "" : savedCard.modelData.uuid
                }
                Rectangle { visible: savedCard.expanded; Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.preferredHeight: 1; color: Colors.border }
                RowLayout {
                    visible: savedCard.expanded
                    Layout.fillWidth: true; Layout.leftMargin: 14; Layout.rightMargin: 14; Layout.bottomMargin: 10; spacing: 8
                    CcText { text: "Auto-join"; font.pixelSize: 12 }
                    CcSwitch { checked: savedCard.modelData.autojoin; enabled: !root.controller.network.busy; onClicked: root.controller.network.run({ action: "autojoin", uuid: savedCard.modelData.uuid, enabled: !checked }) }
                    Item { Layout.fillWidth: true }
                    CcButton { visible: !savedCard.modelData.connected; text: "Connect"; implicitHeight: 28; enabled: !root.controller.network.busy; onClicked: root.controller.connectNetwork(savedCard.modelData) }
                    CcButton { text: "Forget network"; implicitHeight: 28; danger: true; color: "transparent"; enabled: !root.controller.network.busy; onClicked: root.controller.network.run({ action: "forget", uuid: savedCard.modelData.uuid }) }
                }
            }
        }
    }
    CcEmptyState { Layout.fillWidth: true; visible: root.filtered.length === 0; text: "No saved networks found" }
}
