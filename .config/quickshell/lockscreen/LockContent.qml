import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../clock"
import "../core"
import "../controlcenter"

Rectangle {
    id: root
    required property var state
    color: "#13202b"
    property bool reveal: false
    property bool powerOpen: false
    property bool appeared: false
    property real entranceProgress: appeared && !state.closing ? 1 : 0
    Behavior on entranceProgress { NumberAnimation { duration: root.state.closing ? 220 : 360; easing.type: Easing.OutCubic } }
    Component.onCompleted: Qt.callLater(() => { appeared = true })
    onPowerOpenChanged: { if (!powerOpen) Qt.callLater(() => password.forceActiveFocus()) }
    readonly property real uiScale: Math.min(1.4, Math.max(0.6, Math.min(width / 1440, height / 900)))
    SystemClock { id: clock; precision: SystemClock.Minutes }
    NetworkState { id: network; active: true }
    Item {
        id: scene
        anchors.fill: parent
        opacity: root.entranceProgress
        Image { anchors.fill: parent; source: root.state.wallpaper; fillMode: Image.PreserveAspectCrop; asynchronous: true }
        Rectangle { anchors.fill: parent; color: "#88081320" }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: "#183c4855" }
                GradientStop { position: 0.65; color: "#10111d27" }
                GradientStop { position: 1; color: "#70081019" }
            }
        }
        Text { x: 40 * root.uiScale; y: 32 * root.uiScale; text: root.state.distro; color: "#f3f3f3"; font.family: "Sans Serif"; font.pixelSize: 17 * root.uiScale; font.bold: true }
        Row {
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 38 * root.uiScale
            spacing: 18 * root.uiScale
            Text { text: network.state.wired ? "\ueb2f" : network.state.current ? "\ue63e" : "\ue648"; color: "#eeeeee"; font.family: Colors.iconFontFamily; font.pixelSize: 20 * root.uiScale }
            Row {
                visible: UPower.displayDevice.isLaptopBattery
                spacing: 5
                Text { text: UPower.onBattery ? "\ue1a4" : "\ue1a3"; color: "#eeeeee"; font.family: Colors.iconFontFamily; font.pixelSize: 20 * root.uiScale }
                Text { text: Math.round(UPower.displayDevice.percentage * 100) + "%"; color: "#eeeeee"; font.pixelSize: 12 * root.uiScale; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.205 - (1 - root.entranceProgress) * 16 * root.uiScale
            spacing: 28 * root.uiScale
            DotMatrixClock {
                anchors.horizontalCenter: parent.horizontalCenter
                timeText: Qt.formatDateTime(clock.date, "HH:mm")
                ink: "#f3f3f3"; dotStep: 13 * root.uiScale; dotSize: 10 * root.uiScale; glyphGap: 14 * root.uiScale; topInset: 0
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.date, "dddd").toUpperCase() + "   /   " + Qt.formatDateTime(clock.date, "dd MMMM yyyy").toUpperCase()
                color: "#eeeeee"; font.family: Colors.fontFamily; font.pixelSize: 15 * root.uiScale
            }
        }
        Column {
            id: form
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height * 0.53 + (1 - root.entranceProgress) * 20 * root.uiScale
            width: Math.min(420 * root.uiScale, parent.width - 40)
            spacing: 14 * root.uiScale
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64 * root.uiScale; height: width; radius: width / 2
                color: "#3346525e"; border.color: "#80909ba5"
                Text { anchors.centerIn: parent; text: "\ue7fd"; font.family: Colors.iconFontFamily; font.pixelSize: 30 * root.uiScale; color: "#f3f3f3" }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.state.displayName; color: "#f3f3f3"; font.family: "Sans Serif"; font.pixelSize: 23 * root.uiScale; font.bold: true }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: root.state.preview ? "Lock screen preview" : "Session locked"; color: "#c0c5ca"; font.family: "Sans Serif"; font.pixelSize: 12 * root.uiScale }
            RowLayout {
                width: parent.width; spacing: 8 * root.uiScale
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 48 * root.uiScale
                    radius: 12 * root.uiScale; color: "#ed17191b"
                    border.color: root.state.error ? "#ee827a" : password.activeFocus ? "#a0a9b0" : "#657079"
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14 * root.uiScale
                        anchors.rightMargin: 6 * root.uiScale
                        spacing: 10 * root.uiScale
                        Text {
                            Layout.preferredWidth: 20 * root.uiScale
                            Layout.alignment: Qt.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: "\ue899"; color: "#bfc3c7"
                            font.family: Colors.iconFontFamily; font.pixelSize: 19 * root.uiScale
                        }
                        TextField {
                            id: password
                            Layout.fillWidth: true; Layout.fillHeight: true
                            padding: 0; leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
                            verticalAlignment: TextInput.AlignVCenter
                            placeholderText: "Enter password"; placeholderTextColor: "#aaadb0"
                            color: "#f3f3f3"; font.family: "Sans Serif"; font.pixelSize: 13 * root.uiScale
                            echoMode: root.reveal ? TextInput.Normal : TextInput.Password
                            enabled: !root.state.busy && !root.powerOpen
                            background: Item {}
                            selectByMouse: true
                            inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                            onAccepted: root.submit()
                            Keys.onEscapePressed: { clear(); root.reveal = false; root.powerOpen = false }
                            Component.onCompleted: forceActiveFocus()
                            Accessible.name: "Password"
                        }
                        LockButton {
                            Layout.preferredWidth: 32 * root.uiScale; Layout.preferredHeight: 36 * root.uiScale
                            Layout.minimumWidth: 32 * root.uiScale; Layout.maximumWidth: 32 * root.uiScale
                            uiScale: root.uiScale; glyphSize: 18 * root.uiScale
                            glyph: root.reveal ? "\ue8f5" : "\ue8f4"
                            background: Item {}
                            onClicked: { root.reveal = !root.reveal; password.forceActiveFocus() }
                            Accessible.name: root.reveal ? "Hide password" : "Show password"
                        }
                    }
                }
                LockButton { primary: true; glyph: "\ue5c8"; uiScale: root.uiScale; Layout.minimumWidth: 48 * root.uiScale; Layout.maximumWidth: 48 * root.uiScale; Layout.preferredWidth: 48 * root.uiScale; Layout.preferredHeight: 48 * root.uiScale; enabled: !root.state.busy; onClicked: root.submit(); Accessible.name: "Unlock" }
            }
            Text {
                width: parent.width; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                text: root.state.busy ? "Checking…" : root.state.error || "Press Enter to unlock"
                color: root.state.error ? "#ffaca5" : "#b8bec5"; font.family: "Sans Serif"; font.pixelSize: 11 * root.uiScale
            }
        }
        Connections {
            target: root.state
            function onClearPassword() { password.clear(); root.reveal = false; password.forceActiveFocus() }
        }
        LockButton {
            anchors.bottom: parent.bottom; anchors.right: parent.right; anchors.margins: 40 * root.uiScale
            width: 100 * root.uiScale; height: 40 * root.uiScale
            uiScale: root.uiScale; glyphColor: "#f15a52"; glyphSize: 18 * root.uiScale
            text: "Power"; glyph: "\ue8ac"; onClicked: { root.powerOpen = !root.powerOpen }
        }
        PowerModal {
            anchors.fill: parent
            controller: root
            opened: root.powerOpen && !root.state.closing
            lockedSession: true
        }
    } // scene
    function submit() { root.reveal = false; root.state.submit(password.text) }
    function runCommand(command) {
        if (state.preview) { state.error = "Power actions are disabled in preview"; powerOpen = false; return }
        if (powerProc.running) return
        powerProc.command = command
        powerProc.running = true
        powerOpen = false
    }
    Process { id: powerProc; onExited: (code, status) => { if (code !== 0) root.state.error = "Power action failed" } }
}
