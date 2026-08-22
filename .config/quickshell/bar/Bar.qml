import Quickshell
import QtQuick
import QtQuick.Layouts
import "../core"
import "../launcher"
import "../volume"
import "../network"
import "../bluetooth"
import "../clock"
import "../notifications"
import "../power"
import "../wallpaper"
import "../media"
import "../dock"

PanelWindow {
    id: bar

    required property var modelData
    readonly property var barScreen: modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: 38
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Colors.bg, 0.55)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: PopupManager.close()
    }

    PopupCatcher {
        barScreen: bar.barScreen
    }

    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        LauncherButton {
            barScreen: bar.barScreen
        }

        DockToggle {
            barScreen: bar.barScreen
        }

        Workspaces {
            barScreen: bar.barScreen
        }

        ActiveWindow {
            Layout.leftMargin: 5
        }
    }

    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 5
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Media {
            barScreen: bar.barScreen
        }

        Tray {
            barWindow: bar
        }

        IconButton {
            icon: "\ue3b8"
            fgColor: Colors.accent
            command: ["sh", "-c", "sleep 0.1 && hyprpicker -a -f hex && notify-send 'Color copied to clipboard'"]
        }

        WallpaperMenuButton {
            barScreen: bar.barScreen
        }

        Volume {
            barScreen: bar.barScreen
        }

        Bluetooth {
            barScreen: bar.barScreen
        }

        Network {
            barScreen: bar.barScreen
        }

        Clock {
            barScreen: bar.barScreen
        }

        NotifBadge {
            barScreen: bar.barScreen
        }

        PowerButton {
            barScreen: bar.barScreen
        }
    }
}
