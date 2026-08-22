pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    readonly property alias notifications: server.trackedNotifications
    property bool clearing: false

    function dismissAll() {
        clearing = true
        clearAllTimer.start()
    }

    Timer {
        id: clearAllTimer
        interval: 130
        onTriggered: {
            const values = [...server.trackedNotifications.values]
            for (let i = 0; i < values.length; i++)
                values[i].tracked = false
            root.clearing = false
        }
    }

    NotificationServer {
        id: server

        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyImagesSupported: true
        imageSupported: true
        persistenceSupported: true
        keepOnReload: true

        onNotification: notification => {
            notification.tracked = true
        }
    }
}
