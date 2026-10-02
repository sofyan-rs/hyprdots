import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../core"
import "../controlcenter"

Item {
    id: root
    required property var barScreen
    property real maximumWidth: 650
    property int selectedMenu: -1
    property var trail: []
    property real popupLeft: 0
    property bool emptyTimedOut: false
    readonly property bool open: PopupManager.activeId === "globalmenu" && PopupManager.activeScreen === barScreen
    readonly property var menus: GlobalMenuState.state.menus
    readonly property string appName: {
        const appClass = GlobalMenuState.state.class
        const entry = appClass ? DesktopEntries.heuristicLookup(appClass) : null
        if (appClass.toLowerCase() === "com.microsoft.vscode" || appClass.toLowerCase() === "code" || (entry && entry.name === "Visual Studio Code")) return "Code"
        return entry ? entry.name : (appClass || "Desktop")
    }
    implicitWidth: Math.min(maximumWidth, menuBar.implicitWidth)
    implicitHeight: 30
    clip: true
    IpcHandler {
        target: "globalmenu-ui-" + root.barScreen.name
        function openHeading(label: string): bool {
            for (let i = 0; i < root.menus.length; i++) {
                if (root.menus[i].label === label) {
                    root.showMenu(root.menus[i].id, menuButtons.itemAt(i), false)
                    return true
                }
            }
            return false
        }
        function openSubmenu(label: string): bool {
            const node = root.entries.find(item => item.label === label && item.submenu && item.enabled)
            if (!root.open || !node) return false
            root.trail = root.trail.concat([node.id])
            GlobalMenuState.request("open", node.id)
            return true
        }
        function inspect(): string { return JSON.stringify({app: root.appName, open: root.open, entries: root.entries}) }
        function dismiss(): void { PopupManager.close() }
    }
    function findNode(id, nodes) {
        for (const node of nodes) {
            if (node.id === id) return node
            const result = findNode(id, node.children || [])
            if (result) return result
        }
        return null
    }
    readonly property var currentNode: trail.length ? findNode(trail[trail.length - 1], menus) : null
    readonly property var entries: currentNode ? currentNode.children.filter(node => node.visible) : []
    readonly property bool hasIndicators: entries.some(node => node.icon || node.toggle_type || node.checked)
    onCurrentNodeChanged: if (open && trail.length && currentNode === null) PopupManager.close()
    onOpenChanged: emptyTimedOut = false
    onSelectedMenuChanged: emptyTimedOut = false
    Timer {
        interval: 1000
        running: root.open && root.entries.length === 0
        onTriggered: root.emptyTimedOut = true
    }
    function showMenu(id, button, toggle) {
        if (toggle && open && selectedMenu === id) { PopupManager.close(); return }
        selectedMenu = id
        trail = [id]
        const point = button.mapToItem(null, 0, 0)
        popupLeft = Math.max(4, Math.min(barScreen.width - popup.implicitWidth - 4, point.x))
        if (!open) PopupManager.toggle("globalmenu", barScreen)
        GlobalMenuState.request("open", id)
    }
    RowLayout {
        id: menuBar
        anchors.verticalCenter: parent.verticalCenter
        width: implicitWidth
        height: root.implicitHeight
        spacing: 4
        CcText {
            Layout.maximumWidth: 140
            Layout.rightMargin: 8
            Layout.preferredHeight: root.implicitHeight
            Layout.alignment: Qt.AlignVCenter
            verticalAlignment: Text.AlignVCenter
            text: root.appName
            font.pixelSize: 13
            font.bold: true
        }
        Repeater {
            id: menuButtons
            model: root.menus
            delegate: Rectangle {
                id: menuButton
                required property var modelData
                implicitWidth: title.implicitWidth + 20; implicitHeight: 30; radius: 7
                Layout.minimumWidth: implicitWidth
                Layout.alignment: Qt.AlignVCenter
                color: root.open && root.selectedMenu === modelData.id ? Colors.surfaceHover : (hover.containsMouse ? Colors.surface : "transparent")
                CcText {
                    id: title
                    anchors.fill: parent
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: menuButton.modelData.label
                    font.pixelSize: 13
                }
                MouseArea {
                    id: hover; anchors.fill: parent; hoverEnabled: true; enabled: menuButton.modelData.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showMenu(menuButton.modelData.id, menuButton, true)
                    onEntered: if (root.open) root.showMenu(menuButton.modelData.id, menuButton, false)
                }
            }
        }
    }
    PanelWindow {
        id: popup
        screen: root.barScreen
        visible: root.open && root.currentNode !== null
        anchors { top: true; left: true }
        margins.top: Colors.barHeight + Colors.popupTopGap
        margins.left: root.popupLeft
        implicitWidth: Math.min(360, root.barScreen.width - 16)
        implicitHeight: Math.min(menuColumn.implicitHeight + 16, root.barScreen.height - Colors.barHeight - 24)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-global-menu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        Rectangle { anchors.fill: parent; radius: 14; color: Colors.bgAlt; border.width: 1; border.color: Colors.border }
        Flickable {
            anchors.fill: parent; anchors.margins: 8; clip: true
            contentHeight: menuColumn.implicitHeight; boundsBehavior: Flickable.StopAtBounds
            ColumnLayout {
                id: menuColumn
                width: parent.width; spacing: 2
                CcButton {
                    visible: root.trail.length > 1
                    Layout.fillWidth: true; text: root.currentNode ? root.currentNode.label : ""; icon: "\ue5c4"; color: Colors.surface
                    onClicked: root.trail = root.trail.slice(0, -1)
                }
                Repeater {
                    model: root.entries
                    delegate: Rectangle {
                        id: entry
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: modelData.separator ? 9 : 38
                        radius: 8
                        color: menuMouse.containsMouse && !modelData.separator ? Qt.alpha(Colors.accent, 0.14) : "transparent"
                        opacity: modelData.enabled ? 1 : 0.4
                        Rectangle { visible: entry.modelData.separator; anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: Colors.border }
                        RowLayout {
                            visible: !entry.modelData.separator
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 10
                            Item {
                                visible: root.hasIndicators
                                Layout.preferredWidth: 18; Layout.preferredHeight: 18
                                IconImage { anchors.fill: parent; visible: entry.modelData.icon !== ""; source: entry.modelData.icon ? Quickshell.iconPath(entry.modelData.icon) : "" }
                                Text { anchors.centerIn: parent; visible: entry.modelData.checked; text: "\ue5ca"; font.family: Colors.iconFontFamily; font.pixelSize: 18; color: Colors.fg }
                            }
                            CcText { Layout.fillWidth: true; text: entry.modelData.label; font.pixelSize: 13 }
                            CcText { text: entry.modelData.shortcut; font.pixelSize: 11; color: Colors.fgAlt }
                            Text { visible: entry.modelData.submenu; text: "\ue5cc"; font.family: Colors.iconFontFamily; font.pixelSize: 18; color: Colors.fgAlt }
                        }
                        MouseArea {
                            id: menuMouse; anchors.fill: parent; enabled: entry.modelData.enabled && !entry.modelData.separator
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (entry.modelData.submenu) {
                                    root.trail = root.trail.concat([entry.modelData.id])
                                    GlobalMenuState.request("open", entry.modelData.id)
                                } else {
                                    GlobalMenuState.request("activate", entry.modelData.id, root.currentNode.id)
                                    PopupManager.close()
                                }
                            }
                        }
                    }
                }
                CcText {
                    visible: root.entries.length === 0
                    Layout.fillWidth: true
                    Layout.margins: 10
                    text: root.emptyTimedOut ? "No available actions" : "Loading menu…"
                    color: Colors.fgAlt
                    font.pixelSize: 13
                }
            }
        }
    }
}
