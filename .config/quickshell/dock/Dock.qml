import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "../core"

PanelWindow {
    id: root

    readonly property bool open: DockState.open

    screen: DockState.screen
    visible: open
    color: "transparent"
    exclusionMode: ExclusionMode.Auto
    WlrLayershell.namespace: "quickshell-dock"
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        bottom: true
        left: true
        right: true
    }
    margins.bottom: 8

    implicitHeight: content.implicitHeight

    property var pinnedIds: []

    FileView {
        id: pinnedFile
        path: Quickshell.env("HOME") + "/.cache/quickshell/dock-pinned.json"
        onLoaded: {
            try {
                const parsed = JSON.parse(text())
                if (Array.isArray(parsed))
                    root.pinnedIds = parsed
            } catch (e) {
                root.pinnedIds = []
            }
        }
        onLoadFailed: root.pinnedIds = []
    }

    function savePinned() {
        pinnedFile.setText(JSON.stringify(root.pinnedIds))
    }

    function togglePin(item) {
        if (!item.id)
            return
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
            const it = { id: pid, name: entry.name, icon: entry.icon, entry: entry, pinned: true, running: false, toplevel: null, windowCount: 0 }
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
                byId[id].toplevel = tl
                byId[id].windowCount++
                continue
            }

            const key = id || ("appid:" + appId)
            if (byId[key]) {
                byId[key].running = true
                byId[key].toplevel = tl
                byId[key].windowCount++
                continue
            }

            const it = {
                id: id,
                name: entry ? entry.name : (tl.title || appId || "Window"),
                icon: entry ? entry.icon : "application-x-executable",
                entry: entry,
                pinned: false,
                running: true,
                toplevel: tl,
                windowCount: 1
            }
            items.push(it)
            byId[key] = it
        }

        return items
    }

    function launch(item) {
        if (item.running && item.toplevel && item.toplevel.wayland) {
            item.toplevel.wayland.activate()
        } else if (item.entry) {
            item.entry.execute()
        }
    }

    Rectangle {
        id: content
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: dockRow.implicitWidth + 20
        implicitHeight: dockRow.implicitHeight + 16
        radius: Colors.radius + 6
        color: Qt.alpha(Colors.bgAlt, 0.96)
        border.width: 1
        border.color: Colors.border

        Row {
            id: dockRow
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: root.dockItems

                delegate: Item {
                    id: iconSlot

                    required property var modelData
                    required property int index

                    width: 42
                    height: 54
                    opacity: 0

                    Component.onCompleted: opacity = 1

                    Behavior on opacity {
                        NumberAnimation { duration: 160; easing.type: Easing.OutQuad }
                    }

                    ClippingRectangle {
                        id: iconVisual
                        width: 40
                        height: 40
                        radius: 10
                        color: Colors.bg
                        border.width: 1
                        border.color: Colors.border
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter

                        SequentialAnimation on y {
                            id: bounceAnim
                            running: false
                            NumberAnimation { to: -14; duration: 110; easing.type: Easing.OutQuad }
                            NumberAnimation { to: 0; duration: 180; easing.type: Easing.OutBounce }
                        }

                        IconImage {
                            anchors.fill: parent
                            anchors.margins: 6
                            source: Quickshell.iconPath(iconSlot.modelData.icon, "application-x-executable")
                        }

                        Text {
                            visible: !iconSlot.modelData.pinned
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
                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    root.togglePin(iconSlot.modelData)
                                    return
                                }
                                bounceAnim.start()
                                root.launch(iconSlot.modelData)
                            }
                        }
                    }

                    Row {
                        visible: iconSlot.modelData.running
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 3

                        Repeater {
                            model: Math.min(iconSlot.modelData.windowCount, 4)

                            delegate: Rectangle {
                                width: 4
                                height: 4
                                radius: 2
                                color: Colors.accent
                            }
                        }
                    }
                }
            }

            Text {
                visible: root.dockItems.length === 0
                text: "No pinned or running apps"
                font.family: Colors.fontFamily
                font.pixelSize: Colors.fontSize - 4
                color: Colors.fgAlt
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
