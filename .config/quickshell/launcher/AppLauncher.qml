import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../core"

PanelWindow {
    id: root

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            let targetScreen = Quickshell.screens[0]
            for (const s of Quickshell.screens) {
                if (Hyprland.monitorFor(s) === Hyprland.focusedMonitor) {
                    targetScreen = s
                    break
                }
            }
            PopupManager.toggle("launcher", targetScreen)
        }
    }

    readonly property bool open: PopupManager.activeId === "launcher"

    visible: open
    screen: PopupManager.activeScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "quickshell-launcher"
    WlrLayershell.layer: WlrLayer.Overlay

    implicitWidth: Math.min(590, screen ? screen.width - 32 : 590)
    implicitHeight: Math.min(564, screen ? screen.height - 64 : 564)

    property string query: ""
    property int selectedIndex: 0
    property string sortMode: "recent"
    property var recentIds: []
    // Right-click context menu for a launcher row.
    property var menuEntry: null
    property point menuPos: Qt.point(0, 0)

    onQueryChanged: root.menuEntry = null

    readonly property var filtered: {
        const q = query.toLowerCase().trim()
        const all = DesktopEntries.applications.values
        if (!q)
            return all
        return all.filter(e => {
            if (e.name && e.name.toLowerCase().includes(q))
                return true
            if (e.comment && e.comment.toLowerCase().includes(q))
                return true
            if (e.keywords)
                for (let i = 0; i < e.keywords.length; i++)
                    if (e.keywords[i].toLowerCase().includes(q))
                        return true
            return false
        })
    }

    readonly property var sortedFiltered: {
        const arr = filtered.slice()
        if (sortMode === "az") {
            arr.sort((a, b) => a.name.localeCompare(b.name))
        } else {
            const rank = id => {
                const idx = recentIds.indexOf(id)
                return idx === -1 ? Infinity : idx
            }
            arr.sort((a, b) => {
                const ra = rank(a.id)
                const rb = rank(b.id)
                if (ra !== rb)
                    return ra - rb
                return a.name.localeCompare(b.name)
            })
        }
        return arr
    }

    onOpenChanged: {
        root.menuEntry = null
        if (open) {
            query = ""
            selectedIndex = 0
            searchInput.forceActiveFocus()
        }
    }

    onFilteredChanged: selectedIndex = 0

    function toggleSortMode() {
        sortMode = (sortMode === "recent") ? "az" : "recent"
    }

    function launch(entry) {
        if (!entry)
            return
        const next = recentIds.filter(id => id !== entry.id)
        next.unshift(entry.id)
        recentIds = next.slice(0, 30)
        recentFile.setText(JSON.stringify(recentIds))
        entry.execute()
        PopupManager.close()
    }

    function openMenu(entry, pos) {
        root.menuEntry = entry
        root.menuPos = pos
    }

    function moveSelection(delta) {
        if (sortedFiltered.length === 0)
            return
        selectedIndex = (selectedIndex + delta + sortedFiltered.length) % sortedFiltered.length
        list.positionViewAtIndex(selectedIndex, ListView.Contain)
    }

    FileView {
        id: recentFile
        path: Quickshell.env("HOME") + "/.cache/quickshell/launcher-recent.json"
        onLoaded: {
            try {
                const parsed = JSON.parse(text())
                if (Array.isArray(parsed))
                    root.recentIds = parsed
            } catch (e) {
                root.recentIds = []
            }
        }
        onLoadFailed: root.recentIds = []
    }

    Item {
        id: content
        anchors.fill: parent
        transformOrigin: Item.Center

        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.94
        y: root.open ? 0 : -12

        Behavior on opacity {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }
        Behavior on y {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            radius: 20
            color: Colors.glass
            border.width: 1
            border.color: Colors.border
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 12
                color: Colors.surface

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 12

                    Text {
                        text: "\ue8b6"
                        font.family: Colors.iconFontFamily
                        font.pixelSize: 22
                        color: Colors.fg
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        text: root.query
                        font.family: Colors.fontFamily
                        font.pixelSize: 18
                        color: Colors.fg
                        clip: true
                        selectByMouse: true
                        onTextChanged: root.query = text

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Down) {
                                root.moveSelection(1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Up) {
                                root.moveSelection(-1)
                                event.accepted = true
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.launch(root.sortedFiltered[root.selectedIndex])
                                event.accepted = true
                            } else if (event.key === Qt.Key_Escape) {
                                if (root.menuEntry)
                                    root.menuEntry = null
                                else
                                    PopupManager.close()
                                event.accepted = true
                            }
                        }

                        Text {
                            visible: searchInput.text.length === 0
                            text: "Search apps..."
                            font.family: Colors.fontFamily
                            font.pixelSize: 18
                            color: Colors.fgAlt
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        radius: 8
                        color: sortToggleArea.containsMouse ? Colors.border : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: root.sortMode === "recent" ? "\ue8b3" : "\ue053"
                            font.family: Colors.iconFontFamily
                            font.pixelSize: 20
                            color: Colors.fgAlt
                        }

                        MouseArea {
                            id: sortToggleArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleSortMode()
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.preferredHeight: 20

                Text {
                    text: "APPLICATIONS"
                    font.family: Colors.fontFamily
                    font.pixelSize: 10
                    color: Colors.accent
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: root.sortedFiltered.length + (root.sortedFiltered.length === 1 ? " result" : " results")
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: Colors.fgAlt
                }
            }

            ListView {
                id: list
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: root.sortedFiltered
                currentIndex: root.selectedIndex
                spacing: 2
                boundsBehavior: Flickable.StopAtBounds

                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: "No applications found"
                    font.family: Colors.fontFamily
                    font.pixelSize: 14
                    color: Colors.fgAlt
                }

                delegate: Rectangle {
                    id: appRow
                    required property var modelData
                    required property int index
                    readonly property bool selected: index === root.selectedIndex

                    width: list.width
                    height: 56
                    radius: 10
                    color: selected ? Colors.fg : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 14
                        spacing: 14

                        Rectangle {
                            Layout.preferredWidth: 36
                            Layout.preferredHeight: 36
                            radius: 10
                            color: appRow.selected ? Qt.alpha(Colors.bg, 0.12) : Qt.alpha(Colors.fg, 0.08)

                            IconImage {
                                id: appIcon
                                anchors.centerIn: parent
                                implicitSize: 32
                                source: appRow.modelData.icon
                                    ? Quickshell.iconPath(appRow.modelData.icon, true) : ""
                                visible: source.toString().length > 0
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: !appIcon.visible
                                text: "\ue5c3"
                                font.family: Colors.iconFontFamily
                                font.pixelSize: 22
                                color: appRow.selected ? Colors.bg : Colors.fg
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    Layout.fillWidth: true
                                    Layout.maximumWidth: Math.ceil(implicitWidth) + 1
                                    text: appRow.modelData.name
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 14
                                    font.bold: true
                                    textFormat: Text.PlainText
                                    elide: Text.ElideRight
                                    color: appRow.selected ? Colors.bg : Colors.fg
                                }

                                Text {
                                    visible: DockState.isPinned(appRow.modelData.id)
                                    text: "\uf10d"
                                    font.family: Colors.iconFontFamily
                                    font.pixelSize: 13
                                    color: appRow.selected ? Qt.alpha(Colors.bg, 0.6) : Colors.fgAlt
                                }

                                Item { Layout.fillWidth: true }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: text.length > 0
                                text: appRow.modelData.comment || appRow.modelData.genericName || ""
                                font.family: Colors.fontFamily
                                font.pixelSize: 11
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                                color: appRow.selected ? Qt.alpha(Colors.bg, 0.7) : Colors.fgAlt
                            }
                        }

                        Text {
                            visible: appRow.selected
                            text: "Open  ↗"
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            color: Colors.bg
                        }
                    }

                    MouseArea {
                        id: rowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onPositionChanged: if (!root.menuEntry) root.selectedIndex = appRow.index
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                root.selectedIndex = appRow.index
                                root.openMenu(appRow.modelData, mapToItem(content, mouse.x, mouse.y))
                                return
                            }
                            root.launch(appRow.modelData)
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Colors.border
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.preferredHeight: 24
                spacing: 20

                Repeater {
                    model: [
                        { key: "↑↓", label: "Navigate" },
                        { key: "↵", label: "Open" },
                        { key: "Esc", label: "Close" },
                        { key: "RMB", label: "Pin to dock" }
                    ]

                    delegate: RowLayout {
                        required property var modelData
                        spacing: 6

                        Rectangle {
                            Layout.preferredWidth: Math.max(26, keyLabel.implicitWidth + 12)
                            Layout.preferredHeight: 21
                            radius: 5
                            color: Qt.alpha(Colors.fg, 0.08)

                            Text {
                                id: keyLabel
                                anchors.centerIn: parent
                                text: modelData.key
                                font.family: Colors.fontFamily
                                font.pixelSize: 10
                                color: Colors.fg
                            }
                        }

                        Text {
                            text: modelData.label
                            font.family: Colors.fontFamily
                            font.pixelSize: 10
                            color: Colors.fgAlt
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }
        }

        MouseArea {
            anchors.fill: parent
            visible: root.menuEntry !== null
            acceptedButtons: Qt.AllButtons
            onPressed: root.menuEntry = null
        }

        Rectangle {
            id: entryMenu
            visible: root.menuEntry !== null
            readonly property bool pinned: root.menuEntry ? DockState.isPinned(root.menuEntry.id) : false
            readonly property var actions: [
                { key: "open", label: "Open", icon: "\ue89e" },
                { key: "pin", label: entryMenu.pinned ? "Unpin from dock" : "Pin to dock", icon: entryMenu.pinned ? "\ue6f9" : "\uf10d" }
            ]
            x: Math.min(root.menuPos.x, content.width - width - 8)
            y: Math.min(root.menuPos.y, content.height - height - 8)
            width: 200
            height: entryMenuColumn.implicitHeight + 12
            radius: 12
            // Opaque: the menu sits inside the launcher surface, so nothing blurs behind it.
            color: Qt.alpha(Colors.surfaceAlt, 1)
            border.width: 1
            border.color: Colors.border

            onVisibleChanged: if (visible) entryMenuAppear.restart()
            NumberAnimation { id: entryMenuAppear; target: entryMenu; property: "opacity"; from: 0; to: 1; duration: 120 }

            Column {
                id: entryMenuColumn
                anchors.fill: parent
                anchors.margins: 6
                spacing: 2

                Text {
                    width: parent.width
                    leftPadding: 8
                    topPadding: 4
                    bottomPadding: 6
                    text: root.menuEntry ? root.menuEntry.name : ""
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    font.bold: true
                    color: Colors.fgAlt
                }

                Repeater {
                    model: entryMenu.actions

                    delegate: Rectangle {
                        id: entryAction
                        required property var modelData
                        width: entryMenuColumn.width
                        height: 32
                        radius: 8
                        color: entryActionArea.containsMouse ? Colors.border : "transparent"

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 10

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: entryAction.modelData.icon
                                font.family: Colors.iconFontFamily
                                font.pixelSize: 15
                                color: Colors.fgAlt
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: entryAction.modelData.label
                                font.family: Colors.fontFamily
                                font.pixelSize: 12
                                color: Colors.fg
                            }
                        }

                        MouseArea {
                            id: entryActionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // Clearing menuEntry destroys this delegate, so grab
                                // everything we need before touching it.
                                const launcher = root
                                const entry = launcher.menuEntry
                                const key = entryAction.modelData.key
                                launcher.menuEntry = null
                                if (!entry)
                                    return
                                if (key === "open")
                                    launcher.launch(entry)
                                else
                                    DockState.togglePinned(entry.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
