import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    required property var barWindow
    property var trayItem: null
    property var trail: []
    property real anchorX: 0
    property int selectedIndex: -1
    property bool emptyTimedOut: false
    property var branchOpener: null
    readonly property bool open: PopupManager.activeId === "tray"
        && PopupManager.activeScreen === barWindow.screen
    readonly property var currentOpener: trail.length ? branchOpener : topMenu
    readonly property var entries: currentOpener ? currentOpener.children.values : []

    function label(text) {
        // DBus menus use & for mnemonics and && for a literal ampersand.
        return text.replace(/&&/g, "\u0000").replace(/&/g, "").replace(/\u0000/g, "&")
    }

    function show(item, x) {
        if (!item.hasMenu) return
        if (open && trayItem === item) { close(); return }
        trail = []
        selectedIndex = -1
        trayItem = item
        anchorX = x
        emptyTimedOut = false
        if (!open) PopupManager.toggle("tray", barWindow.screen)
    }

    function close() {
        if (open) PopupManager.close()
    }

    function back() {
        trail = trail.slice(0, -1)
        selectedIndex = -1
    }

    function activate(entry) {
        if (!entry || entry.isSeparator || !entry.enabled) return
        if (entry.hasChildren) {
            // Retain ancestor openers so their menu entries stay alive.
            trail = trail.concat([entry])
            selectedIndex = -1
        } else {
            entry.triggered()
            close()
        }
    }

    function moveSelection(step) {
        const start = selectedIndex < 0 ? (step > 0 ? -1 : 0) : selectedIndex
        for (let offset = 1; offset <= entries.length; offset++) {
            const index = (start + step * offset + entries.length) % entries.length
            if (!entries[index].isSeparator && entries[index].enabled) {
                selectedIndex = index
                const row = rows.itemAt(index)
                if (row) {
                    if (row.y < scroller.contentY) scroller.contentY = row.y
                    else if (row.y + row.height > scroller.contentY + scroller.height)
                        scroller.contentY = row.y + row.height - scroller.height
                }
                return
            }
        }
    }

    onOpenChanged: {
        if (!open) {
            trail = []
            trayItem = null
            selectedIndex = -1
        }
    }
    onEntriesChanged: {
        selectedIndex = -1
        emptyTimedOut = false
        scroller.contentY = 0
    }
    onTrailChanged: {
        branchOpener = null
        // Repeater delegates may be created after the trail binding updates.
        Qt.callLater(() => {
            const branch = branches.itemAt(trail.length - 1)
            branchOpener = branch ? branch.opener : null
        })
    }

    QsMenuOpener {
        id: topMenu
        menu: root.open && root.trayItem ? root.trayItem.menu : null
    }
    Connections {
        target: SystemTray.items
        function onValuesChanged() {
            if (root.open && SystemTray.items.values.indexOf(root.trayItem) === -1) root.close()
        }
    }
    Connections {
        target: root.trayItem
        function onHasMenuChanged() {
            if (root.trayItem && !root.trayItem.hasMenu) root.close()
        }
    }
    Repeater {
        id: branches
        model: root.trail
        onItemAdded: (index, item) => {
            if (index === root.trail.length - 1) root.branchOpener = item.opener
        }
        delegate: Item {
            required property var modelData
            property alias opener: branchMenu
            QsMenuOpener { id: branchMenu; menu: modelData }
        }
    }
    Timer {
        interval: 1000
        running: root.open && root.entries.length === 0 && !root.emptyTimedOut
        onTriggered: root.emptyTimedOut = true
    }

    PanelWindow {
        id: popup
        screen: root.barWindow.screen
        visible: root.open && root.trayItem !== null && root.trayItem.hasMenu
        anchors { top: true; left: true }
        margins.top: Colors.barHeight + Colors.popupTopGap
        margins.left: Math.max(8, Math.min(root.anchorX, screen.width - implicitWidth - 8))
        implicitWidth: Math.min(320, screen.width - 16)
        implicitHeight: Math.min(menuColumn.implicitHeight + 16, screen.height - Colors.barHeight - 24)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-tray-menu"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        onVisibleChanged: if (visible) keyboard.forceActiveFocus()

        Rectangle {
            anchors.fill: parent
            radius: 14
            color: Colors.bgAlt
            border.width: 1
            border.color: Colors.border
        }
        Item {
            id: keyboard
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: root.close()
            Keys.onUpPressed: root.moveSelection(-1)
            Keys.onDownPressed: root.moveSelection(1)
            Keys.onLeftPressed: if (root.trail.length) root.back()
            Keys.onRightPressed: {
                const entry = root.entries[root.selectedIndex]
                if (entry && entry.hasChildren) root.activate(entry)
            }
            Keys.onReturnPressed: root.activate(root.entries[root.selectedIndex])
            Keys.onEnterPressed: root.activate(root.entries[root.selectedIndex])

            Flickable {
                id: scroller
                anchors.fill: parent
                anchors.margins: 8
                clip: true
                contentHeight: menuColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: menuColumn
                    width: scroller.width
                    spacing: 2

                    Rectangle {
                        visible: root.trail.length > 0
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 8
                        color: backMouse.containsMouse ? Colors.surfaceHover : "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10
                            Text {
                                visible: root.trail.length > 0
                                text: "\ue5c4"
                                font.family: Colors.iconFontFamily
                                font.pixelSize: 18
                                color: Colors.accent
                            }
                            Text {
                                Layout.fillWidth: true
                                text: root.trail.length ? root.label(root.trail[root.trail.length - 1].text) : ""
                                font.family: Colors.fontFamily
                                font.pixelSize: 12
                                font.bold: true
                                color: Colors.fgAlt
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }
                        }
                        MouseArea {
                            id: backMouse
                            anchors.fill: parent
                            enabled: root.trail.length > 0
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.back()
                        }
                    }
                    Rectangle {
                        visible: root.trail.length > 0
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        implicitHeight: 1
                        color: Colors.border
                    }
                    Repeater {
                        id: rows
                        model: root.currentOpener ? root.currentOpener.children : null
                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: modelData.isSeparator ? 9 : 38
                            radius: 8
                            color: !modelData.isSeparator && modelData.enabled && root.selectedIndex === index
                                ? Qt.alpha(Colors.accent, 0.14) : "transparent"
                            opacity: modelData.isSeparator || modelData.enabled ? 1 : 0.4
                            Behavior on color { ColorAnimation { duration: 100 } }

                            Rectangle {
                                visible: row.modelData.isSeparator
                                anchors.verticalCenter: parent.verticalCenter
                                x: 10
                                width: parent.width - 20
                                height: 1
                                color: Colors.border
                            }
                            RowLayout {
                                visible: !row.modelData.isSeparator
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10
                                Item {
                                    visible: row.modelData.icon !== "" || row.modelData.buttonType !== QsMenuButtonType.None
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                    IconImage {
                                        anchors.fill: parent
                                        visible: row.modelData.buttonType === QsMenuButtonType.None && source !== ""
                                        source: row.modelData.icon
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: row.modelData.buttonType !== QsMenuButtonType.None
                                        text: row.modelData.buttonType === QsMenuButtonType.RadioButton
                                            ? (row.modelData.checkState === Qt.Checked ? "\ue837" : "\ue836")
                                            : (row.modelData.checkState === Qt.Checked ? "\ue834"
                                                : row.modelData.checkState === Qt.PartiallyChecked ? "\ue909" : "\ue835")
                                        font.family: Colors.iconFontFamily
                                        font.pixelSize: 18
                                        color: row.modelData.checkState !== Qt.Unchecked ? Colors.accent : Colors.fgAlt
                                    }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: root.label(row.modelData.text)
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 13
                                    color: Colors.fg
                                    elide: Text.ElideRight
                                    textFormat: Text.PlainText
                                }
                                Text {
                                    visible: row.modelData.hasChildren
                                    text: "\ue5cc"
                                    font.family: Colors.iconFontFamily
                                    font.pixelSize: 18
                                    color: Colors.fgAlt
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: !row.modelData.isSeparator && row.modelData.enabled
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: root.selectedIndex = row.index
                                onExited: if (root.selectedIndex === row.index) root.selectedIndex = -1
                                onClicked: root.activate(row.modelData)
                            }
                        }
                    }
                    Text {
                        visible: root.entries.length === 0
                        Layout.fillWidth: true
                        Layout.margins: 10
                        text: root.emptyTimedOut ? "No available actions" : "Loading menu…"
                        font.family: Colors.fontFamily
                        font.pixelSize: 13
                        color: Colors.fgAlt
                    }
                }
            }
        }
    }
}
