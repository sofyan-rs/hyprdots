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

    implicitWidth: 560
    implicitHeight: 420

    property string query: ""
    property int selectedIndex: 0
    property string sortMode: "recent"
    property var recentIds: []

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
        radius: Colors.radius
        color: Colors.bgAlt
        border.width: 1
        border.color: Colors.border
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: ""
                font.family: Colors.iconFontFamily
                font.pixelSize: Colors.fontSize + 2
                color: Colors.fgAlt
            }

            TextInput {
                id: searchInput
                Layout.fillWidth: true
                text: root.query
                font.family: Colors.fontFamily
                font.pixelSize: Colors.fontSize
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
                        PopupManager.close()
                        event.accepted = true
                    }
                }

                Text {
                    visible: searchInput.text.length === 0
                    text: "Search apps..."
                    font.family: Colors.fontFamily
                    font.pixelSize: Colors.fontSize
                    color: Colors.fgAlt
                }
            }

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: Colors.radius
                color: sortToggleArea.containsMouse ? Colors.border : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: root.sortMode === "recent" ? "\ue8b3" : "\ue053"
                    font.family: Colors.iconFontFamily
                    font.pixelSize: Colors.fontSize
                    color: Colors.fgAlt
                }

                MouseArea {
                    id: sortToggleArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.toggleSortMode()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Colors.border
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: root.sortedFiltered
            currentIndex: root.selectedIndex
            spacing: 2

            delegate: Rectangle {
                id: appRow

                required property var modelData
                required property int index

                width: list.width
                height: 44
                radius: Colors.radius
                color: index === root.selectedIndex ? Colors.secondary : (rowArea.containsMouse ? Colors.border : "transparent")

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    IconImage {
                        implicitSize: 24
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        source: Quickshell.iconPath(appRow.modelData.icon, "application-x-executable")
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: appRow.modelData.name
                            font.family: Colors.fontFamily
                            font.pixelSize: Colors.fontSize
                            font.bold: true
                            elide: Text.ElideRight
                            color: index === root.selectedIndex ? Colors.accentText : Colors.fg
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: appRow.modelData.comment || ""
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            elide: Text.ElideRight
                            color: index === root.selectedIndex ? Colors.accentText : Colors.fgAlt
                        }
                    }
                }

                MouseArea {
                    id: rowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.selectedIndex = appRow.index
                    onClicked: root.launch(appRow.modelData)
                }
            }
        }
    }
    }
}
