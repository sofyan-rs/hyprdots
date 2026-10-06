import Quickshell
import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root
    required property var controller
    property string displayedPage: "hub"
    property bool ready: false
    Component.onCompleted: { displayedPage = controller.page; ready = true }
    Connections {
        target: root.controller
        function onPageChanged() {
            if (!root.ready) return
            if (!root.controller.open) {
                pageTransition.stop()
                root.displayedPage = root.controller.page
                column.opacity = 1
                flick.contentY = 0
            } else pageTransition.restart()
        }
    }
    SequentialAnimation {
        id: pageTransition
        NumberAnimation { target: column; property: "opacity"; to: 0; duration: 70; easing.type: Easing.OutQuad }
        ScriptAction {
            script: {
                root.displayedPage = root.controller.page
                flick.contentY = 0
            }
        }
        NumberAnimation { target: column; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutCubic }
    }
    implicitWidth: 470
    implicitHeight: column.implicitHeight + 40
    Rectangle { anchors.fill: parent; radius: 20; color: Colors.bgAlt; border.width: 1; border.color: Colors.border }
    Flickable {
        id: flick
        anchors.fill: parent; anchors.margins: 20
        clip: true
        contentWidth: width; contentHeight: column.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: column
            width: flick.width; spacing: 14
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                CcButton { visible: root.displayedPage !== "hub"; icon: "\ue5c4"; implicitWidth: 36; onClicked: root.controller.page = root.displayedPage === "saved" ? "connections" : "hub" }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 5
                    CcText { Layout.fillWidth: true; text: ({hub: "Control Center", connections: "Connections", saved: "Saved networks", settings: "Quick settings"})[root.displayedPage]; font.pixelSize: 21; font.bold: true }
                    CcText { Layout.fillWidth: true; text: ({hub: "Everything important, in reach", connections: "Manage networks and nearby devices", saved: "Networks this device remembers", settings: "Personalize your desktop"})[root.displayedPage]; font.pixelSize: 11; color: Colors.fgAlt }
                }
                RowLayout {
                    visible: root.displayedPage === "hub"
                    spacing: 8
                    CcButton { icon: "\ue312"; implicitWidth: 36; onClicked: PopupManager.toggle("keybinds", root.controller.barScreen) }
                    CcButton { icon: "\ue429"; implicitWidth: 36; onClicked: PopupManager.toggle("wallpaper", root.controller.barScreen) }
                    CcButton { icon: "\ue8ac"; implicitWidth: 36; danger: true; color: Qt.alpha(Colors.accent, 0.12); onClicked: root.controller.powerOpen = true }
                }
            }
            CcText { Layout.fillWidth: true; visible: root.controller.network.error !== "" && (root.displayedPage === "connections" || root.displayedPage === "saved"); text: root.controller.network.error; font.pixelSize: 11; color: Colors.accent; wrapMode: Text.Wrap; maximumLineCount: 4 }
            Loader {
                Layout.fillWidth: true
                sourceComponent: ({hub: hub, connections: connections, saved: saved, settings: settings})[root.displayedPage]
            }
        }
    }
    Component { id: hub; HubPage { controller: root.controller } }
    Component { id: connections; ConnectionsPage { controller: root.controller } }
    Component { id: saved; SavedNetworksPage { controller: root.controller } }
    Component {
        id: settings
        ColumnLayout {
            spacing: 8
            CcRow { Layout.fillWidth: true; title: "Wallpaper"; subtitle: "Choose a desktop background"; icon: "\ue3f4"; onClicked: PopupManager.toggle("wallpaper", root.controller.barScreen) }
            CcRow { Layout.fillWidth: true; title: "Color picker"; subtitle: "Copy a color from the screen"; icon: "\ue3b8"; onClicked: root.controller.runCommand(["sh", "-c", "sleep 0.1 && hyprpicker -a -f hex && notify-send 'Color copied to clipboard'"]) }
            CcRow { Layout.fillWidth: true; title: "Advanced network settings"; subtitle: "VPN, Ethernet and enterprise Wi-Fi"; icon: "\ue63e"; onClicked: root.controller.runCommand(["nm-connection-editor"]) }
            CcRow { Layout.fillWidth: true; title: "Toggle dock"; subtitle: "Show or hide the application dock"; icon: "\ue875"; onClicked: { DockState.toggle(root.controller.barScreen); PopupManager.close() } }
            CcRow { Layout.fillWidth: true; title: "Lock dock positions"; subtitle: DockState.positionsLocked ? "Enabled" : "Disabled"; icon: "\ue899"; onClicked: DockState.toggleLock() }
        }
    }
}
