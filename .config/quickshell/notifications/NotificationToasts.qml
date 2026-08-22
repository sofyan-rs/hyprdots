import Quickshell
import QtQuick

PanelWindow {
    id: root

    anchors {
        top: true
        right: true
    }
    margins {
        top: 46
        right: 10
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    implicitWidth: 320
    implicitHeight: Math.max(1, column.implicitHeight)

    Column {
        id: column
        width: parent.width
        spacing: 8

        Repeater {
            model: NotificationHub.notifications

            delegate: ToastCard {
                required property var modelData
                width: column.width
                notification: modelData
            }
        }
    }
}
