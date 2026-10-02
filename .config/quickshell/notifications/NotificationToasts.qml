import Quickshell
import Quickshell.Wayland
import QtQuick
import "../core"

PanelWindow {
    id: root

    anchors {
        top: true
        right: true
    }
    margins {
        top: Colors.barHeight + 10
        right: 14
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "quickshell-notifications"

    implicitWidth: 410
    implicitHeight: Math.max(1, column.implicitHeight)

    readonly property bool hasShownToast: {
        for (let i = 0; i < toastRepeater.count; i++) {
            const toast = toastRepeater.itemAt(i)
            if (toast && toast.shown)
                return true
        }
        return false
    }
    // Open before the height animation starts; keep mapped until it finishes.
    visible: hasShownToast || column.implicitHeight > 0

    Column {
        id: column
        width: parent.width
        spacing: 8

        Repeater {
            id: toastRepeater
            model: NotificationHub.notifications

            delegate: ToastCard {
                required property var modelData
                width: column.width
                notification: modelData
            }
        }
    }
}
