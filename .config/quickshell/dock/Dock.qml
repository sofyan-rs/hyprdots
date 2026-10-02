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

    readonly property bool open: DockState.open
    readonly property bool vertical: DockState.position !== "bottom"

    screen: DockState.screen
    visible: open
    color: "transparent"
    exclusiveZone: root.vertical ? content.implicitWidth : content.implicitHeight
    WlrLayershell.namespace: "quickshell-dock"
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        bottom: true
        top: root.vertical
        left: DockState.position !== "right"
        right: DockState.position !== "left"
    }
    margins.bottom: root.vertical ? 0 : 5
    margins.top: root.vertical ? Colors.barHeight : 0
    margins.left: DockState.position === "left" ? 5 : 0
    margins.right: DockState.position === "right" ? 5 : 0
    implicitWidth: content.implicitWidth + 8 + 360

    readonly property int pickerListMaxHeight: Math.min(280, Math.max(56, (root.screen ? root.screen.height : 800) - content.height - pickerHeader.height - 64))

    // Keep the surface geometry stable when opening or closing the picker.
    // The input mask below limits clicks to the visible dock and picker.
    implicitHeight: content.implicitHeight + 8 + pickerHeader.height + 24 + root.pickerListMaxHeight

    // Keep the transparent area around the dock clickable by other windows.
    mask: Region {
        item: content
        Region {
            x: windowPicker.x + windowPicker.width * (1 - windowPicker.scale) / 2
            y: windowPicker.y + windowPicker.height * (1 - windowPicker.scale) + pickerSlide.y
            width: windowPicker.visible ? windowPicker.width * windowPicker.scale : 0
            height: windowPicker.visible ? windowPicker.height * windowPicker.scale : 0
        }
    }

    IpcHandler {
        target: "dock"
        function reveal(): void { DockState.screen = Quickshell.screens[0]; DockState.open = true }
        function hide(): void { DockState.close() }
    }
    property string selectedKey: ""
    readonly property var selectedItem: root.dockItems.find(item => item.key === root.selectedKey) || null
    readonly property var selectedWindows: root.selectedItem ? root.selectedItem.windows : []
    readonly property var selectedSlot: dockRepeater.itemAt(root.dockItems.findIndex(item => item.key === root.selectedKey))
    readonly property real selectedIconX: content.x + dockRow.x + (selectedSlot ? selectedSlot.x + selectedSlot.width / 2 : dockRow.width / 2)
    readonly property real selectedIconY: content.y + dockRow.y + (selectedSlot ? selectedSlot.y + 17 : dockRow.height / 2)
    readonly property real surfaceX: DockState.position === "right" ? (screen ? screen.width : width) - width - 5 : DockState.position === "left" ? 5 : 0
    readonly property real surfaceY: root.vertical ? Colors.barHeight : (screen ? screen.height : height) - height - 5

    Connections {
        target: DockState
        function onPositionChanged() { root.selectedKey = "" }
    }
    Connections {
        target: PopupManager
        function onActiveIdChanged() { if (PopupManager.activeId !== "") root.selectedKey = "" }
    }

    PanelWindow {
        id: pickerCatcher
        screen: root.screen
        visible: root.open && root.selectedWindows.length > 0
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-dock-catcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        mask: Region {
            width: pickerCatcher.width; height: pickerCatcher.height
            Region {
                intersection: Intersection.Subtract
                x: root.surfaceX + content.x; y: root.surfaceY + content.y
                width: content.width; height: content.height
            }
            Region {
                intersection: Intersection.Subtract
                x: root.surfaceX + windowPicker.x + windowPicker.width * (1 - windowPicker.scale) / 2
                y: root.surfaceY + windowPicker.y + windowPicker.height * (1 - windowPicker.scale) + pickerSlide.y
                width: windowPicker.width * windowPicker.scale; height: windowPicker.height * windowPicker.scale
            }
        }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: root.selectedKey = "" }
        Item { focus: true; Keys.onEscapePressed: root.selectedKey = "" }
    }

    onOpenChanged: {
        root.selectedKey = ""
        root.cancelDrag()
    }
    onDockItemsChanged: {
        root.cancelDrag()
        if (root.selectedKey && !root.dockItems.some(item => item.key === root.selectedKey && item.windows.length > 0))
            root.selectedKey = ""
    }

    property var pinnedIds: []
    property var orderKeys: []
    readonly property bool positionsLocked: DockState.positionsLocked
    property bool settingsLoaded: false
    property string dragKey: ""
    property int dragFromIndex: -1
    property int dragTargetIndex: -1
    property real dragOffset: 0

    onPositionsLockedChanged: {
        root.cancelDrag()
        if (root.settingsLoaded) {
            root.orderKeys = root.rememberOrder()
            root.savePinned()
        }
    }

    FileView {
        id: pinnedFile
        path: Quickshell.env("HOME") + "/.cache/quickshell/dock-pinned.json"
        onLoaded: {
            root.settingsLoaded = false
            try {
                const parsed = JSON.parse(text())
                // Older versions stored just the list of pinned app IDs.
                if (Array.isArray(parsed)) {
                    root.pinnedIds = parsed
                } else if (parsed && typeof parsed === "object") {
                    root.pinnedIds = Array.isArray(parsed.pinnedIds) ? parsed.pinnedIds.filter(id => typeof id === "string") : []
                    root.orderKeys = Array.isArray(parsed.orderKeys) ? [...new Set(parsed.orderKeys.filter(key => typeof key === "string"))] : []
                }
            } catch (e) {
                root.pinnedIds = []
            }
            root.settingsLoaded = true
        }
        onLoadFailed: {
            root.pinnedIds = []
            root.settingsLoaded = true
        }
    }

    function savePinned() {
        pinnedFile.setText(JSON.stringify({ pinnedIds: root.pinnedIds, orderKeys: root.orderKeys, locked: root.positionsLocked }))
    }

    function cancelDrag() {
        root.dragKey = ""
        root.dragFromIndex = -1
        root.dragTargetIndex = -1
        root.dragOffset = 0
    }

    function rememberOrder() {
        return root.orderKeys.concat(root.dockItems.map(item => item.key).filter(key => root.orderKeys.indexOf(key) < 0))
    }

    function moveItem(key, targetIndex) {
        if (root.positionsLocked)
            return
        const fromIndex = root.dockItems.findIndex(item => item.key === key)
        if (fromIndex < 0 || targetIndex < 0 || targetIndex >= root.dockItems.length || fromIndex === targetIndex)
            return
        const targetKey = root.dockItems[targetIndex].key
        const order = root.rememberOrder()
        order.splice(order.indexOf(key), 1)
        order.splice(order.indexOf(targetKey) + (fromIndex < targetIndex ? 1 : 0), 0, key)
        root.orderKeys = order
        root.savePinned()
    }

    function togglePin(item) {
        if (root.positionsLocked || !item.id)
            return
        root.orderKeys = root.rememberOrder()
        const idx = root.pinnedIds.indexOf(item.id)
        if (idx >= 0)
            root.pinnedIds = root.pinnedIds.filter(id => id !== item.id)
        else
            root.pinnedIds = root.pinnedIds.concat([item.id])
        root.savePinned()
    }

    readonly property var dockItems: {
        const items = []
        const byId = {}

        for (const pid of root.pinnedIds) {
            const entry = DesktopEntries.byId(pid)
            if (!entry)
                continue
            const it = { key: pid, id: pid, name: entry.name, icon: entry.icon, entry: entry, pinned: true, running: false, windows: [], windowCount: 0 }
            items.push(it)
            byId[pid] = it
        }

        const toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : []
        for (const tl of toplevels) {
            const appId = (tl.wayland && tl.wayland.appId) ? tl.wayland.appId : ""
            if (!appId)
                continue
            const entry = DesktopEntries.heuristicLookup(appId)
            const id = entry ? entry.id : null

            if (id && byId[id]) {
                byId[id].running = true
                byId[id].windows.push(tl)
                byId[id].windowCount++
                continue
            }

            const key = id || ("appid:" + appId)
            if (byId[key]) {
                byId[key].running = true
                byId[key].windows.push(tl)
                byId[key].windowCount++
                continue
            }

            const it = {
                key: key,
                id: id,
                name: entry ? entry.name : (tl.title || appId || "Window"),
                icon: entry ? entry.icon : "application-x-executable",
                entry: entry,
                pinned: false,
                running: true,
                windows: [tl],
                windowCount: 1
            }
            items.push(it)
            byId[key] = it
        }

        // Retain the saved positions for apps that are temporarily closed, too.
        const ranks = new Map(root.orderKeys.map((key, index) => [key, index]))
        return items.sort((a, b) => (ranks.has(a.key) ? ranks.get(a.key) : root.orderKeys.length)
            - (ranks.has(b.key) ? ranks.get(b.key) : root.orderKeys.length))
    }

    function launch(item) {
        if (item.windows.length > 1) {
            root.selectedKey = root.selectedKey === item.key ? "" : item.key
        } else if (item.windows.length === 1) {
            root.activateWindow(item.windows[0])
        } else if (item.entry) {
            root.selectedKey = ""
            item.entry.execute()
        }
    }

    function activateWindow(toplevel) {
        if (!toplevel || !toplevel.wayland)
            return
        toplevel.wayland.activate()
        root.selectedKey = ""
    }

    Rectangle {
        id: windowPicker
        visible: root.selectedWindows.length > 0
        onVisibleChanged: {
            if (visible)
                pickerAppear.restart()
            else
                pickerAppear.stop()
        }
        transformOrigin: Item.Bottom
        transform: Translate { id: pickerSlide }

        ParallelAnimation {
            id: pickerAppear
            NumberAnimation {
                target: windowPicker
                property: "scale"
                from: 0.92
                to: 1
                duration: 240
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: pickerSlide
                property: "y"
                from: 14
                to: 0
                duration: 240
                easing.type: Easing.OutCubic
            }
        }

        x: DockState.position === "left" ? content.x + content.width + 8
            : DockState.position === "right" ? content.x - width - 8
            : Math.max(0, Math.min(root.width - width, root.selectedIconX - width / 2))
        y: root.vertical ? Math.max(0, Math.min(root.height - height, root.selectedIconY - pickerHeader.height / 2 - 12))
            : content.y - height - 8
        width: Math.min(360, root.width - 16)
        height: pickerHeader.height + windowList.height + 24
        radius: Colors.radius + 6
        color: Qt.alpha(Colors.bgAlt, 0.98)
        border.width: 1
        border.color: Colors.border

        RowLayout {
            id: pickerHeader
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 12
            height: 26
            spacing: 8

            IconImage {
                implicitSize: 20
                source: Quickshell.iconPath(root.selectedItem ? root.selectedItem.icon : "application-x-executable", "application-x-executable")
            }

            Text {
                Layout.fillWidth: true
                text: root.selectedItem ? root.selectedItem.name + " · " + root.selectedWindows.length : ""
                elide: Text.ElideRight
                font.family: Colors.fontFamily
                font.pixelSize: Colors.fontSize - 2
                font.bold: true
                color: Colors.fg
            }

            Rectangle {
                implicitWidth: 24
                implicitHeight: 24
                radius: 6
                color: closeArea.containsMouse ? Colors.bg : "transparent"
                Text {
                    anchors.centerIn: parent
                    text: "×"
                    font.pixelSize: 20
                    color: Colors.fgAlt
                }
                MouseArea {
                    id: closeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.selectedKey = ""
                }
            }
        }

        ListView {
            id: windowList
            anchors.top: pickerHeader.bottom
            anchors.topMargin: 6
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            height: Math.min(contentHeight, root.pickerListMaxHeight)
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: root.selectedWindows

            onModelChanged: positionViewAtBeginning()

            delegate: Rectangle {
                id: windowRow
                required property var modelData
                width: ListView.view.width
                height: 56
                radius: Colors.radius + 2
                readonly property bool active: !!modelData && modelData.activated
                color: windowArea.containsMouse ? Colors.bg : (active ? Qt.alpha(Colors.accent, 0.12) : "transparent")
                border.width: active ? 1 : 0
                border.color: Qt.alpha(Colors.accent, 0.45)

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: 12
                    spacing: 3

                    Text {
                        width: parent.width
                        text: windowRow.modelData ? (windowRow.modelData.title || "Untitled window") : ""
                        elide: Text.ElideRight
                        font.family: Colors.fontFamily
                        font.pixelSize: Colors.fontSize - 3
                        color: Colors.fg
                    }

                    Text {
                        width: parent.width
                        text: windowRow.modelData
                            ? (windowRow.modelData.workspace ? "Workspace " + windowRow.modelData.workspace.name : "Window") + (windowRow.active ? " · Active" : "")
                            : ""
                        elide: Text.ElideRight
                        font.family: Colors.fontFamily
                        font.pixelSize: Colors.fontSize - 5
                        color: windowRow.active ? Colors.accent : Colors.fgAlt
                    }
                }

                MouseArea {
                    id: windowArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.activateWindow(windowRow.modelData)
                }
            }
        }
    }

    Rectangle {
        id: content
        implicitWidth: dockRow.implicitWidth + 20
        implicitHeight: dockRow.implicitHeight + 12
        width: implicitWidth
        height: implicitHeight
        x: DockState.position === "left" ? 0 : DockState.position === "right" ? root.width - width : (root.width - width) / 2
        y: root.vertical ? (root.height - height) / 2 : root.height - height
        radius: 14
        color: Colors.bgAlt
        border.width: 1
        border.color: Colors.border

        Grid {
            id: dockRow
            anchors.centerIn: parent
            columns: root.vertical ? 1 : Math.max(1, root.dockItems.length)
            spacing: 6

            Repeater {
                id: dockRepeater
                model: root.dockItems

                delegate: Item {
                    id: iconSlot

                    required property var modelData
                    required property int index

                    width: 34
                    height: 42
                    z: root.dragKey === modelData.key ? 1 : 0
                    readonly property real displacement: {
                            if (!root.dragKey) return 0
                            if (root.dragKey === iconSlot.modelData.key) return root.dragOffset
                            const step = (root.vertical ? iconSlot.height : iconSlot.width) + dockRow.spacing
                            if (root.dragFromIndex < root.dragTargetIndex && iconSlot.index > root.dragFromIndex && iconSlot.index <= root.dragTargetIndex) return -step
                            if (root.dragFromIndex > root.dragTargetIndex && iconSlot.index >= root.dragTargetIndex && iconSlot.index < root.dragFromIndex) return step
                            return 0
                    }
                    transform: Translate {
                        y: root.vertical ? iconSlot.displacement : 0
                        x: root.vertical ? 0 : iconSlot.displacement
                    }

                    ClippingRectangle {
                        id: iconVisual
                        width: 34
                        height: 34
                        radius: 8
                        readonly property bool active: iconSlot.modelData.windows.some(window => window.activated)
                        color: active ? Colors.fg : Colors.surface
                        border.width: root.selectedKey === iconSlot.modelData.key ? 1 : 0
                        border.color: root.selectedKey === iconSlot.modelData.key ? Colors.accent : Colors.border
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter

                        IconImage {
                            anchors.fill: parent
                            anchors.margins: 5
                            source: Quickshell.iconPath(iconSlot.modelData.icon, "application-x-executable")
                        }

                        Text {
                            visible: !root.positionsLocked && !iconSlot.modelData.pinned
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 2
                            text: "\uf10d"
                            font.family: Colors.iconFontFamily
                            font.pixelSize: 11
                            color: Colors.fgAlt
                            opacity: pinArea.containsMouse ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation { duration: 100 }
                            }

                            MouseArea {
                                id: pinArea
                                anchors.fill: parent
                                anchors.margins: -4
                                hoverEnabled: true
                                enabled: iconSlot.modelData.id !== null
                                onClicked: root.togglePin(iconSlot.modelData)
                            }
                        }

                        MouseArea {
                            id: clickArea
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            hoverEnabled: true
                            cursorShape: root.positionsLocked ? Qt.PointingHandCursor : (pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                            property real pressRowX: 0
                            property bool dragged: false

                            onPressed: mouse => {
                                dragged = false
                                const point = mapToItem(dockRow, mouse.x, mouse.y)
                                pressRowX = root.vertical ? point.y : point.x
                            }
                            onPositionChanged: mouse => {
                                if (root.positionsLocked || !pressed || !(pressedButtons & Qt.LeftButton))
                                    return
                                const point = mapToItem(dockRow, mouse.x, mouse.y)
                                const offset = (root.vertical ? point.y : point.x) - pressRowX
                                if (!dragged && Math.abs(offset) < 6)
                                    return
                                if (!dragged) {
                                    dragged = true
                                    root.selectedKey = ""
                                    root.dragKey = iconSlot.modelData.key
                                    root.dragFromIndex = iconSlot.index
                                }
                                const step = (root.vertical ? iconSlot.height : iconSlot.width) + dockRow.spacing
                                root.dragOffset = Math.max(-root.dragFromIndex * step, Math.min((root.dockItems.length - 1 - root.dragFromIndex) * step, offset))
                                root.dragTargetIndex = Math.max(0, Math.min(root.dockItems.length - 1, Math.round(root.dragFromIndex + root.dragOffset / step)))
                            }
                            onReleased: {
                                if (!dragged || root.dragKey !== iconSlot.modelData.key)
                                    return
                                const key = root.dragKey
                                const target = root.dragTargetIndex
                                root.cancelDrag()
                                root.moveItem(key, target)
                            }
                            onCanceled: root.cancelDrag()
                            onClicked: mouse => {
                                if (dragged)
                                    return
                                if (mouse.button === Qt.RightButton) {
                                    root.togglePin(iconSlot.modelData)
                                    return
                                }
                                root.launch(iconSlot.modelData)
                            }
                        }
                    }

                    Row {
                        visible: iconSlot.modelData.running
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 0
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 3

                        Repeater {
                            model: Math.min(iconSlot.modelData.windowCount, 4)

                            delegate: Rectangle {
                                width: 3
                                height: 3
                                radius: 1.5
                                color: Colors.accent
                            }
                        }
                    }
                }
            }

        }
    }
}
