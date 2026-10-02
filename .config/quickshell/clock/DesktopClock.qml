import Quickshell
import Quickshell.Wayland
import QtQuick
import "../core"

PanelWindow {
    required property var modelData
    screen: modelData
    anchors { top: true; left: true }
    margins.left: 48
    margins.top: Colors.barHeight + 48
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    WlrLayershell.namespace: "quickshell-desktop-clock"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    DesktopClockContent { id: content }
}
