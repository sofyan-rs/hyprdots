import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import "../core"

PanelWindow {
    id: root
    required property var modelData
    // Room around the content so the drop shadow is not clipped.
    readonly property int shadowPad: 28
    screen: modelData
    anchors { top: true; left: true }
    margins.left: 48 - shadowPad
    margins.top: Colors.barHeight + 48 - shadowPad
    implicitWidth: content.implicitWidth + shadowPad * 2
    implicitHeight: content.implicitHeight + shadowPad * 2
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    WlrLayershell.namespace: "quickshell-desktop-clock"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    DesktopClockContent {
        id: content
        x: root.shadowPad
        y: root.shadowPad
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowOpacity: 0.9
            shadowBlur: 0.7
            blurMax: 24
            shadowVerticalOffset: 2
        }
    }
}
