import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import "../core"

Scope {
    id: root
    required property var modelData
    required property var wallpaperPicker
    property real clickX: 0
    property real clickY: 0
    readonly property bool open: PopupManager.activeId === "desktop-menu"
        && PopupManager.activeScreen === modelData

    // Bottom surfaces receive clicks only on desktop space below app windows.
    PanelWindow {
        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "quickshell-desktop-menu"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: mouse => {
                root.clickX = mouse.x
                root.clickY = mouse.y
                PopupManager.toggle("desktop-menu", root.modelData)
            }
        }
    }

    PanelWindow {
        id: popup
        screen: root.modelData
        visible: root.open
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "quickshell-desktop-menu-popup"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        onVisibleChanged: if (visible) changeButton.forceActiveFocus()

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onClicked: PopupManager.close()
        }

        Rectangle {
            id: menu
            x: Math.max(8, Math.min(root.clickX, popup.width - width - 8))
            y: Math.max(8, Math.min(root.clickY, popup.height - height - 8))
            width: 232
            height: actions.implicitHeight + 12
            radius: 12
            color: Colors.bgAlt
            border.width: 1
            border.color: Colors.border

            // Consume clicks in the menu padding as well as on its buttons.
            MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

            Column {
                id: actions
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
                spacing: 2

                Button {
                    id: changeButton
                    width: parent.width
                    height: 40
                    text: "Change Wallpaper"
                    padding: 12
                    Keys.onEscapePressed: PopupManager.close()
                    Keys.onDownPressed: nextButton.forceActiveFocus()
                    background: Rectangle {
                        radius: 7
                        color: changeButton.hovered || changeButton.activeFocus ? Colors.surfaceHover : "transparent"
                    }
                    contentItem: Text {
                        text: changeButton.text
                        font.family: Colors.fontFamily
                        font.pixelSize: 13
                        color: Colors.fg
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: PopupManager.toggle("wallpaper", root.modelData)
                }

                Button {
                    id: nextButton
                    width: parent.width
                    height: 40
                    text: "Next Wallpaper"
                    padding: 12
                    enabled: root.wallpaperPicker != null && !root.wallpaperPicker.busy
                        && root.wallpaperPicker.library.length > 0
                    Keys.onEscapePressed: PopupManager.close()
                    Keys.onUpPressed: changeButton.forceActiveFocus()
                    background: Rectangle {
                        radius: 7
                        color: nextButton.hovered || nextButton.activeFocus ? Colors.surfaceHover : "transparent"
                    }
                    contentItem: Text {
                        text: nextButton.text
                        font.family: Colors.fontFamily
                        font.pixelSize: 13
                        color: nextButton.enabled ? Colors.fg : Colors.fgAlt
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        PopupManager.close()
                        root.wallpaperPicker.nextWallpaper()
                    }
                }
            }
        }
    }
}
