import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../core"
import "../controlcenter"

PanelWindow {
    id: root

    readonly property bool open: PopupManager.activeId === "keybinds"
    property string query: ""
    property string selectedCategory: "All shortcuts"
    readonly property var categories: [
        { name: "All shortcuts", icon: "\ue871" },
        { name: "Applications", icon: "\ue5c3" },
        { name: "Shell & session", icon: "\ue8ac" },
        { name: "Windows", icon: "\ue1b1" },
        { name: "Workspaces", icon: "\ue53b" },
        { name: "Screenshots", icon: "\ue3b0" },
        { name: "Media & brightness", icon: "\ue050" }
    ]
    function categoryCount(name) {
        return shortcuts.filter(item => name === "All shortcuts" || item.group === name).length
    }
    // Keep this reference aligned with hypr/config/keybinds.lua.
    readonly property var shortcuts: [
        { group: "Applications", keys: "Super + Return", action: "Open terminal" },
        { group: "Applications", keys: "Super + E", action: "Open file manager" },
        { group: "Applications", keys: "Super + B", action: "Open browser" },
        { group: "Applications", keys: "Alt + Space", action: "Open app launcher" },
        { group: "Shell & session", keys: "Super + K", action: "Toggle keybind reference" },
        { group: "Shell & session", keys: "Super + Shift + W", action: "Open wallpaper picker" },
        { group: "Shell & session", keys: "Super + R", action: "Restart Quickshell" },
        { group: "Shell & session", keys: "Super + L", action: "Lock screen" },
        { group: "Shell & session", keys: "Super + M", action: "Open shutdown / exit session" },
        { group: "Windows", keys: "Super + Q", action: "Close active window" },
        { group: "Windows", keys: "Super + V", action: "Toggle floating" },
        { group: "Windows", keys: "Super + P", action: "Toggle pseudotiling" },
        { group: "Windows", keys: "Super + J", action: "Toggle split direction (dwindle)" },
        { group: "Windows", keys: "Super + W", action: "Switch dwindle / scrolling layout" },
        { group: "Windows", keys: "Alt + ← / → / ↑ / ↓", action: "Focus window in direction" },
        { group: "Windows", keys: "Super + Shift + ← / → / ↑ / ↓", action: "Move window in direction" },
        { group: "Windows", keys: "Super + Ctrl + ← / → / ↑ / ↓", action: "Resize window in direction" },
        { group: "Windows", keys: "Super + Left mouse drag", action: "Move window with mouse" },
        { group: "Windows", keys: "Super + Right mouse drag", action: "Resize window with mouse" },
        { group: "Workspaces", keys: "Super + 1–9 / 0", action: "Switch to workspace 1–10" },
        { group: "Workspaces", keys: "Super + Shift + 1–9 / 0", action: "Move window to workspace 1–10" },
        { group: "Workspaces", keys: "Super + ← / →", action: "Previous / next workspace" },
        { group: "Workspaces", keys: "Super + Scroll down / up", action: "Next / previous workspace" },
        { group: "Workspaces", keys: "Super + S", action: "Toggle scratchpad (magic)" },
        { group: "Workspaces", keys: "Super + Shift + S", action: "Move window to scratchpad" },
        { group: "Screenshots", keys: "Print", action: "Copy selected region to clipboard" },
        { group: "Screenshots", keys: "End", action: "Save focused monitor screenshot" },
        { group: "Media & brightness", keys: "Volume up / down", action: "Raise / lower volume by 5%" },
        { group: "Media & brightness", keys: "Mute", action: "Toggle speaker mute" },
        { group: "Media & brightness", keys: "Mic mute", action: "Toggle microphone mute" },
        { group: "Media & brightness", keys: "Brightness up / down", action: "Raise / lower brightness by 5%" },
        { group: "Media & brightness", keys: "Media play / pause", action: "Toggle playback" },
        { group: "Media & brightness", keys: "Media next / previous", action: "Next / previous track" }
    ]
    readonly property var filtered: {
        const q = query.toLowerCase().trim()
        return shortcuts.filter(item =>
            (selectedCategory === "All shortcuts" || item.group === selectedCategory) &&
            (!q || (item.group + " " + item.keys + " " + item.action).toLowerCase().includes(q)))
    }

    property var displayScreen: Quickshell.screens[0]
    visible: open || card.opacity > 0
    screen: displayScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Math.min(960, screen ? screen.width - 32 : 960)
    implicitHeight: Math.min(720, screen ? screen.height - 80 : 720)
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-keybinds"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    onVisibleChanged: if (visible && open) Qt.callLater(() => search.forceActiveFocus())

    onOpenChanged: {
        if (open) {
            displayScreen = PopupManager.activeScreen
            query = ""
            selectedCategory = "All shortcuts"
            list.contentY = 0
            Qt.callLater(() => search.forceActiveFocus())
        }
    }
    onQueryChanged: list.contentY = 0
    onSelectedCategoryChanged: list.contentY = 0

    Shortcut { sequence: "Escape"; enabled: root.open; onActivated: PopupManager.close() }
    Shortcut { sequence: "Ctrl+F"; enabled: root.open; onActivated: { search.forceActiveFocus(); search.selectAll() } }

    Process {
        id: customizeProcess
        command: ["code", Quickshell.env("HOME") + "/.config/hypr/config/keybinds.lua"]
    }

    IpcHandler {
        target: "keybinds"
        function toggle(): void {
            let targetScreen = Quickshell.screens[0]
            for (const s of Quickshell.screens) {
                if (Hyprland.monitorFor(s) === Hyprland.focusedMonitor) {
                    targetScreen = s
                    break
                }
            }
            PopupManager.toggle("keybinds", targetScreen)
        }
        function close(): void {
            if (root.open) PopupManager.close()
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        enabled: root.open
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.96
        transformOrigin: Item.Center
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        radius: 20
        color: Colors.bgAlt
        border.color: Colors.border

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 20

            RowLayout {
                Layout.fillWidth: true
                spacing: 14
                Rectangle {
                    implicitWidth: 44
                    implicitHeight: 44
                    radius: 12
                    color: Colors.surface
                    Text {
                        anchors.centerIn: parent
                        text: "\ue312"
                        font.family: Colors.iconFontFamily
                        font.pixelSize: 24
                        color: Colors.fg
                    }
                }
                ColumnLayout {
                    spacing: 5
                    Text {
                        text: "Keyboard shortcuts"
                        color: Colors.fg
                        font.family: Colors.fontFamily
                        font.pixelSize: 24
                        font.bold: true
                    }
                    Text {
                        text: "Less clicking. More doing."
                        color: Colors.fgAlt
                        font.family: Colors.fontFamily
                        font.pixelSize: 12
                    }
                }
                Item { Layout.fillWidth: true }
                CcButton {
                    icon: "\ue5cd"
                    implicitWidth: 36
                    onClicked: PopupManager.close()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                radius: 12
                color: Colors.surface
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12
                    Text {
                        text: "\ue8b6"
                        font.family: Colors.iconFontFamily
                        font.pixelSize: 23
                        color: Colors.fg
                    }
                    TextInput {
                        id: search
                        Layout.fillWidth: true
                        color: Colors.fg
                        selectionColor: Colors.accent
                        font.family: Colors.fontFamily
                        font.pixelSize: 15
                        clip: true
                        selectByMouse: true
                        text: root.query
                        onTextChanged: root.query = text
                        Keys.onEscapePressed: PopupManager.close()
                        Keys.onDownPressed: list.contentY = Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + 56)
                        Keys.onUpPressed: list.contentY = Math.max(0, list.contentY - 56)
                        Text {
                            visible: search.text.length === 0
                            text: "Search shortcuts…"
                            color: Colors.fgAlt
                            font: search.font
                        }
                    }
                    Text {
                        text: "Ctrl + F"
                        color: Colors.fgAlt
                        font.family: Colors.fontFamily
                        font.pixelSize: 10
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 24

                ColumnLayout {
                    Layout.preferredWidth: 210
                    Layout.maximumWidth: 210
                    Layout.fillWidth: false
                    Layout.fillHeight: true
                    spacing: 6
                    Repeater {
                        model: root.categories
                        delegate: Rectangle {
                            id: category
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 42
                            readonly property bool selected: root.selectedCategory === modelData.name
                            radius: 10
                            color: selected ? Colors.fg : categoryArea.containsMouse ? Colors.surfaceHover : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 10
                                Text {
                                    text: category.modelData.icon
                                    font.family: Colors.iconFontFamily
                                    font.pixelSize: 18
                                    color: category.selected ? Colors.bg : Colors.fgAlt
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: category.modelData.name
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 11
                                    font.bold: category.selected
                                    color: category.selected ? Colors.bg : Colors.fgMuted
                                }
                                Text {
                                    text: root.categoryCount(category.modelData.name)
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 10
                                    color: category.selected ? Colors.bg : Colors.fgAlt
                                }
                            }
                            MouseArea {
                                id: categoryArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.selectedCategory = category.modelData.name
                                    search.forceActiveFocus()
                                }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 12
                        spacing: 8
                        Text {
                            text: "What is Super?"
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            color: Colors.fg
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "The Windows or ⌘ key on your keyboard."
                            wrapMode: Text.WordWrap
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            color: Colors.fgAlt
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 26
                        Text {
                            text: root.selectedCategory.toUpperCase()
                            color: Colors.accentLight
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: root.filtered.length + " shortcuts"
                            color: Colors.fgAlt
                            font.family: Colors.fontFamily
                            font.pixelSize: 10
                        }
                    }
                    ListView {
                        id: list
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: root.filtered
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        delegate: Item {
                            id: row
                            required property var modelData
                            width: list.width
                            height: Math.max(54, rowContent.implicitHeight + 24)
                            RowLayout {
                                id: rowContent
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 10
                                anchors.rightMargin: 12
                                spacing: 16
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.action
                                    textFormat: Text.PlainText
                                    wrapMode: Text.WordWrap
                                    color: Colors.fg
                                    font.family: Colors.fontFamily
                                    font.pixelSize: 12
                                }
                                Flow {
                                    Layout.preferredWidth: Math.min(280, list.width * 0.50)
                                    Layout.preferredHeight: implicitHeight
                                    layoutDirection: Qt.RightToLeft
                                    spacing: 6
                                    Repeater {
                                        model: row.modelData.keys.split(" + ").reverse()
                                        delegate: Rectangle {
                                            required property string modelData
                                            width: Math.min(keyText.implicitWidth + 18, 260)
                                            height: keyText.implicitHeight + 12
                                            radius: 5
                                            color: Colors.surface
                                            border.color: Colors.border
                                            Text {
                                                id: keyText
                                                anchors.centerIn: parent
                                                text: parent.modelData
                                                color: Colors.fgMuted
                                                font.family: Colors.fontFamily
                                                font.pixelSize: 10
                                            }
                                        }
                                    }
                                }
                            }
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: Colors.border
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: list.count === 0
                            text: "No shortcuts found"
                            color: Colors.fgAlt
                            font.family: Colors.fontFamily
                            font.pixelSize: 14
                        }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Colors.border }
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.preferredHeight: 30
                spacing: 20
                Repeater {
                    model: [
                        { key: "↑↓", label: "Scroll" },
                        { key: "Esc", label: "Close" }
                    ]
                    delegate: RowLayout {
                        required property var modelData
                        spacing: 6
                        Rectangle {
                            Layout.preferredWidth: Math.max(26, footerKey.implicitWidth + 12)
                            Layout.preferredHeight: 21
                            radius: 5
                            color: Qt.alpha(Colors.fg, 0.08)
                            Text {
                                id: footerKey
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
                Rectangle {
                    implicitWidth: 124
                    implicitHeight: 30
                    radius: 8
                    color: customizeArea.containsMouse ? Colors.surfaceHover : Colors.surface
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: "\ue429"
                            color: Colors.fgMuted
                            font.family: Colors.iconFontFamily
                            font.pixelSize: 16
                        }
                        Text {
                            Layout.alignment: Qt.AlignVCenter
                            text: "Customize"
                            color: Colors.fgMuted
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        id: customizeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            customizeProcess.running = true
                            PopupManager.close()
                        }
                    }
                }
            }
        }
    }
}
