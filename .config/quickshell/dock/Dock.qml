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
    // macOS-style sizing: equal padding on every side, with the running dot
    // sitting inside the padding on the screen-edge side.
    readonly property int iconSize: DockState.iconSize
    readonly property int dockPadding: Math.max(6, Math.round(root.iconSize * 0.18))

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
        Region {
            x: contextMenu.x; y: contextMenu.y
            width: contextMenu.visible ? contextMenu.width : 0
            height: contextMenu.visible ? contextMenu.height : 0
        }
    }

    IpcHandler {
        target: "dock"
        function reveal(): void { DockState.screen = Quickshell.screens[0]; DockState.open = true }
        function hide(): void { DockState.close() }
    }
    property string selectedKey: ""
    // Right-click context menu target; mutually exclusive with the window picker.
    property string menuKey: ""
    readonly property var menuItem: root.dockItems.find(item => item.key === root.menuKey) || null
    readonly property string anchorKey: root.menuKey || root.selectedKey
    readonly property var selectedItem: root.dockItems.find(item => item.key === root.selectedKey) || null
    readonly property var selectedWindows: root.selectedItem ? root.selectedItem.windows : []
    readonly property var selectedSlot: dockRepeater.itemAt(root.dockItems.findIndex(item => item.key === root.anchorKey))
    readonly property real selectedIconX: content.x + dockRow.x + (selectedSlot ? selectedSlot.x + selectedSlot.width / 2 : dockRow.width / 2)
    readonly property real selectedIconY: content.y + dockRow.y + (selectedSlot ? selectedSlot.y + root.iconSize / 2 : dockRow.height / 2)
    readonly property real surfaceX: DockState.position === "right" ? (screen ? screen.width : width) - width - 5 : DockState.position === "left" ? 5 : 0
    readonly property real surfaceY: root.vertical ? Colors.barHeight : (screen ? screen.height : height) - height - 5

    Connections {
        target: DockState
        function onPositionChanged() { root.closePopups() }
    }
    Connections {
        target: PopupManager
        function onActiveIdChanged() { if (PopupManager.activeId !== "") root.closePopups() }
    }

    PanelWindow {
        id: pickerCatcher
        screen: root.screen
        visible: root.open && (root.selectedWindows.length > 0 || root.menuItem !== null)
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-dock-catcher"
        // One layer below the dock so the dock, picker and menu always stay on
        // top and keep hover, even if the subtracted regions below lag behind.
        WlrLayershell.layer: WlrLayer.Top
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
            Region {
                intersection: Intersection.Subtract
                x: root.surfaceX + contextMenu.x; y: root.surfaceY + contextMenu.y
                width: contextMenu.visible ? contextMenu.width : 0; height: contextMenu.visible ? contextMenu.height : 0
            }
        }
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onPressed: root.closePopups() }
        Item { focus: true; Keys.onEscapePressed: root.closePopups() }
    }

    onOpenChanged: {
        root.closePopups()
        root.cancelDrag()
    }
    onDockItemsChanged: {
        root.cancelDrag()
        if (root.selectedKey && !root.dockItems.some(item => item.key === root.selectedKey && item.windows.length > 0))
            root.selectedKey = ""
        if (root.menuKey && !root.menuItem)
            root.menuKey = ""
    }

    function closePopups() {
        root.selectedKey = ""
        root.menuKey = ""
    }

    function openMenu(item) {
        root.selectedKey = ""
        root.menuKey = root.menuKey === item.key ? "" : item.key
    }

    // Hyprland keeps the last window "activated" after switching to an empty
    // workspace, so it only counts when it sits on the focused workspace.
    function isWindowActive(window) {
        const focused = Hyprland.focusedWorkspace
        return !!window && window.activated && !!window.workspace && !!focused && window.workspace.id === focused.id
    }

    function newWindowAction(item) {
        const actions = item && item.entry ? item.entry.actions : []
        return actions.find(action => /new.*window/i.test(action.id) || /new.*window/i.test(action.name)) || null
    }

    function closeApp(item) {
        for (const window of item.windows)
            if (window && window.wayland)
                window.wayland.close()
    }

    readonly property bool positionsLocked: DockState.positionsLocked
    property string dragKey: ""
    property int dragFromIndex: -1
    property int dragTargetIndex: -1
    property real dragOffset: 0

    onPositionsLockedChanged: {
        root.cancelDrag()
        if (DockState.pinsLoaded) {
            DockState.orderKeys = root.rememberOrder()
            DockState.savePinned()
        }
    }

    function cancelDrag() {
        root.dragKey = ""
        root.dragFromIndex = -1
        root.dragTargetIndex = -1
        root.dragOffset = 0
    }

    function rememberOrder() {
        return DockState.orderKeys.concat(root.dockItems.map(item => item.key).filter(key => DockState.orderKeys.indexOf(key) < 0))
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
        DockState.orderKeys = order
        DockState.savePinned()
    }

    function togglePin(item) {
        if (!item.id)
            return
        DockState.orderKeys = root.rememberOrder()
        DockState.togglePinned(item.id)
    }

    readonly property var dockItems: {
        const items = []
        const byId = {}

        for (const pid of DockState.pinnedIds) {
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
        const ranks = new Map(DockState.orderKeys.map((key, index) => [key, index]))
        return items.sort((a, b) => (ranks.has(a.key) ? ranks.get(a.key) : DockState.orderKeys.length)
            - (ranks.has(b.key) ? ranks.get(b.key) : DockState.orderKeys.length))
    }

    function launch(item) {
        root.menuKey = ""
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
        color: Colors.glass
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
                readonly property bool active: root.isWindowActive(modelData)
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
        id: contextMenu
        visible: root.menuItem !== null
        readonly property var actions: {
            const item = root.menuItem
            if (!item)
                return []
            const list = []
            // Single-instance apps just refocus on execute(), so only offer
            // "New window" when the desktop entry declares a matching action.
            if (item.entry && !item.running)
                list.push({ key: "open", label: "Open", icon: "\ue89e" })
            else if (root.newWindowAction(item))
                list.push({ key: "new", label: "New window", icon: "\ue89e" })
            if (item.id)
                list.push({ key: "pin", label: item.pinned ? "Unpin from dock" : "Pin to dock", icon: item.pinned ? "\ue6f9" : "\uf10d" })
            if (item.running)
                list.push({ key: "close", label: item.windowCount > 1 ? "Close " + item.windowCount + " windows" : "Close", icon: "\ue5cd", danger: true })
            return list
        }
        onVisibleChanged: if (visible) menuAppear.restart()

        NumberAnimation {
            id: menuAppear
            target: contextMenu
            property: "opacity"
            from: 0
            to: 1
            duration: 140
            easing.type: Easing.OutCubic
        }

        x: DockState.position === "left" ? content.x + content.width + 8
            : DockState.position === "right" ? content.x - width - 8
            : Math.max(0, Math.min(root.width - width, root.selectedIconX - width / 2))
        y: root.vertical ? Math.max(0, Math.min(root.height - height, root.selectedIconY - height / 2))
            : content.y - height - 8
        width: 210
        height: menuColumn.implicitHeight + 12
        radius: Colors.radius + 6
        color: Colors.glass
        border.width: 1
        border.color: Colors.border

        Column {
            id: menuColumn
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Text {
                width: parent.width
                leftPadding: 8
                topPadding: 4
                bottomPadding: 6
                text: root.menuItem ? root.menuItem.name : ""
                elide: Text.ElideRight
                font.family: Colors.fontFamily
                font.pixelSize: Colors.fontSize - 4
                font.bold: true
                color: Colors.fgAlt
            }

            Repeater {
                model: contextMenu.actions

                delegate: Rectangle {
                    id: actionRow
                    required property var modelData
                    width: menuColumn.width
                    height: 32
                    radius: Colors.radius + 2
                    color: actionArea.containsMouse ? (modelData.danger ? Qt.alpha(Colors.accent, 0.18) : Colors.bg) : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: actionRow.modelData.icon
                            font.family: Colors.iconFontFamily
                            font.pixelSize: 15
                            color: actionRow.modelData.danger ? Colors.accent : Colors.fgAlt
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: actionRow.modelData.label
                            font.family: Colors.fontFamily
                            font.pixelSize: Colors.fontSize - 3
                            color: actionRow.modelData.danger ? Colors.accent : Colors.fg
                        }
                    }

                    MouseArea {
                        id: actionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Clearing menuKey destroys this delegate, so grab
                            // everything we need before touching it.
                            const dock = root
                            const item = dock.menuItem
                            const key = actionRow.modelData.key
                            dock.menuKey = ""
                            if (!item)
                                return
                            if (key === "open")
                                item.entry.execute()
                            else if (key === "new")
                                dock.newWindowAction(item).execute()
                            else if (key === "pin")
                                dock.togglePin(item)
                            else if (key === "close")
                                dock.closeApp(item)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: content
        implicitWidth: dockRow.implicitWidth + root.dockPadding * 2
        implicitHeight: dockRow.implicitHeight + root.dockPadding * 2
        width: implicitWidth
        height: implicitHeight
        x: DockState.position === "left" ? 0 : DockState.position === "right" ? root.width - width : (root.width - width) / 2
        y: root.vertical ? (root.height - height) / 2 : root.height - height
        radius: Math.round(root.iconSize * 0.4)
        color: Colors.glass
        border.width: 1
        border.color: Colors.border

        Grid {
            id: dockRow
            anchors.centerIn: parent
            columns: root.vertical ? 1 : Math.max(1, root.dockItems.length)
            spacing: 4

            Repeater {
                id: dockRepeater
                model: root.dockItems

                delegate: Item {
                    id: iconSlot

                    required property var modelData
                    required property int index

                    width: root.iconSize
                    height: root.iconSize
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
                        width: root.iconSize
                        height: root.iconSize
                        radius: Math.round(root.iconSize * 0.22)
                        readonly property bool active: iconSlot.modelData.windows.some(window => root.isWindowActive(window))
                        color: active ? Colors.fg : Colors.surface
                        border.width: root.anchorKey === iconSlot.modelData.key ? 1 : 0
                        border.color: Colors.accent
                        scale: clickArea.pressed && root.positionsLocked ? 0.92 : 1

                        Behavior on scale {
                            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                        }

                        IconImage {
                            anchors.fill: parent
                            anchors.margins: Math.max(1, Math.round(root.iconSize * 0.04))
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
                                    root.closePopups()
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
                                    root.openMenu(iconSlot.modelData)
                                    return
                                }
                                root.launch(iconSlot.modelData)
                            }
                        }
                    }

                    // One dot per running app, brighter when it owns the focused window.
                    Rectangle {
                        readonly property bool active: iconSlot.modelData.windows.some(window => root.isWindowActive(window))
                        visible: iconSlot.modelData.running
                        width: 4
                        height: 4
                        radius: 2
                        color: Colors.fg
                        opacity: active ? 0.95 : 0.5
                        x: DockState.position === "left" ? -(root.dockPadding + width) / 2
                            : DockState.position === "right" ? parent.width + (root.dockPadding - width) / 2
                            : (parent.width - width) / 2
                        y: root.vertical ? (parent.height - height) / 2 : parent.height + (root.dockPadding - height) / 2

                        Behavior on opacity {
                            NumberAnimation { duration: 150 }
                        }
                    }
                }
            }

        }
    }
}
