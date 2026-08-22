import Qt.labs.folderlistmodel
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
        target: "wallpaper"

        function toggle(): void {
            let targetScreen = Quickshell.screens[0]
            for (const s of Quickshell.screens) {
                if (Hyprland.monitorFor(s) === Hyprland.focusedMonitor) {
                    targetScreen = s
                    break
                }
            }
            PopupManager.toggle("wallpaper", targetScreen)
        }
    }

    readonly property bool open: PopupManager.activeId === "wallpaper"
    property string folderPath: Quickshell.env("HOME") + "/Pictures/Wallpapers"

    visible: open
    screen: PopupManager.activeScreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "quickshell-wallpaper"
    WlrLayershell.layer: WlrLayer.Overlay

    implicitWidth: 700
    implicitHeight: 520

    property int selectedIndex: 0

    onOpenChanged: {
        if (open) {
            selectedIndex = 0
            grid.forceActiveFocus()
        }
    }

    function setWallpaper(path) {
        setProc.command = ["waypaper", "--wallpaper", path]
        setProc.running = true
        PopupManager.close()
    }

    function moveSelection(delta) {
        const count = folderModel.count
        if (count === 0)
            return
        selectedIndex = (selectedIndex + delta + count) % count
        grid.positionViewAtIndex(selectedIndex, GridView.Contain)
    }

    Process {
        id: setProc
    }

    FileView {
        id: configFile
        path: Quickshell.env("HOME") + "/.config/waypaper/config.ini"
        onLoaded: {
            const m = text().match(/^folder\s*=\s*(.+)$/m)
            if (m) {
                let p = m[1].trim()
                if (p.startsWith("~"))
                    p = Quickshell.env("HOME") + p.slice(1)
                root.folderPath = p
            }
        }
    }

    FolderListModel {
        id: folderModel
        folder: "file://" + root.folderPath
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
        showDirs: false
        sortField: FolderListModel.Name
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
                    text: "\ue1bc"
                    font.family: Colors.iconFontFamily
                    font.pixelSize: Colors.fontSize + 2
                    color: Colors.fgAlt
                }

                Text {
                    Layout.fillWidth: true
                    text: "Wallpaper"
                    font.family: Colors.fontFamily
                    font.pixelSize: Colors.fontSize
                    font.bold: true
                    color: Colors.fg
                }

                Text {
                    text: folderModel.count + " images"
                    font.family: Colors.fontFamily
                    font.pixelSize: 12
                    color: Colors.fgAlt
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.border
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                focus: true

                readonly property int columns: Math.max(1, Math.floor(width / 150))

                cellWidth: width / columns
                cellHeight: 130
                model: folderModel

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Right) {
                        root.moveSelection(1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Left) {
                        root.moveSelection(-1)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Down) {
                        root.moveSelection(columns)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) {
                        root.moveSelection(-columns)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        const item = folderModel.get(root.selectedIndex, "filePath")
                        if (item)
                            root.setWallpaper(item)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Escape) {
                        PopupManager.close()
                        event.accepted = true
                    }
                }

                delegate: Item {
                    id: cell

                    required property string fileName
                    required property string filePath
                    required property int index

                    width: grid.cellWidth
                    height: grid.cellHeight

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 4

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ClippingRectangle {
                                anchors.fill: parent
                                radius: Colors.radius
                                color: Colors.bg

                                Image {
                                    anchors.fill: parent
                                    source: "file://" + cell.filePath
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.width: 200
                                    sourceSize.height: 200
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: Colors.radius
                                color: "transparent"
                                border.width: (thumbArea.containsMouse || cell.index === root.selectedIndex) ? 2 : 1
                                border.color: (thumbArea.containsMouse || cell.index === root.selectedIndex) ? Colors.accent : Colors.border
                            }

                            MouseArea {
                                id: thumbArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.selectedIndex = cell.index
                                onClicked: root.setWallpaper(cell.filePath)
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: cell.fileName
                            font.family: Colors.fontFamily
                            font.pixelSize: 11
                            color: Colors.fgAlt
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideMiddle
                        }
                    }
                }
            }
        }
    }
}
