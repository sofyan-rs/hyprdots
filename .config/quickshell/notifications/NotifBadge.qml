import Quickshell
import Quickshell.Wayland
import QtQuick
import "../core"

Pill {
    id: root

    readonly property int liveCount: NotificationHub.notifications.values.length
    property int count: liveCount
    required property var barScreen

    readonly property bool open: PopupManager.activeId === "notif" && PopupManager.activeScreen === barScreen

    onLiveCountChanged: {
        if (!NotificationHub.clearing)
            count = liveCount
    }

    Connections {
        target: NotificationHub
        function onClearingChanged() {
            if (!NotificationHub.clearing)
                root.count = root.liveCount
        }
    }

    implicitWidth: row.implicitWidth + 20

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: "\ue7f5"
            font.family: Colors.iconFontFamily
            font.pixelSize: Colors.fontSize
            font.bold: true
            color: Colors.secondary
        }

        Text {
            text: root.count
            font.family: Colors.fontFamily
            font.pixelSize: Colors.fontSize
            font.bold: true
            color: Colors.fg
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: PopupManager.toggle("notif", root.barScreen)
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
        margins.top: Colors.barHeight + 2
        margins.right: rightMargin

        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight

        NotificationHistoryPopup {
            id: content
            open: root.open
        }
    }
}
