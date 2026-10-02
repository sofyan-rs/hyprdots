import Quickshell
import Quickshell.Wayland
import QtQuick
import "../core"

Pill {
    id: root

    property string dateFormat: "hh:mm"
    required property var barScreen

    readonly property bool open: PopupManager.activeId === "clock" && PopupManager.activeScreen === barScreen

    bgColor: Colors.clockBg
    implicitWidth: label.implicitWidth + 20

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, root.dateFormat)
        font.family: Colors.fontFamily
        font.pixelSize: root.flat ? Colors.fontSize - 2 : Colors.fontSize
        font.bold: !root.flat
        color: Colors.fg
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PopupManager.toggle("clock", root.barScreen)
    }

    function updatePopupPosition() {
        const screenW = root.barScreen ? root.barScreen.width : 0
        const pos = root.mapToItem(null, root.width, 0)
        popup.rightMargin = Math.max(4, screenW - pos.x)
    }

    onOpenChanged: {
        if (open)
            Qt.callLater(updatePopupPosition)
    }

    PanelWindow {
        id: popup

        property real rightMargin: 20

        screen: root.barScreen
        visible: root.open
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell-popup"
        WlrLayershell.layer: WlrLayer.Overlay

        anchors {
            top: true
            right: true
        }
        margins.top: Colors.barHeight + Colors.popupTopGap
        margins.right: rightMargin

        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight

        CalendarPopup {
            id: content
            open: root.open
        }
    }
}
