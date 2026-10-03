import QtQuick
import Quickshell
import QtQuick.Layouts
import "../core"

Rectangle {
    id: root
    required property var controller
    property bool lockedSession: false
    property var pendingAction: null
    readonly property bool confirming: pendingAction !== null
    readonly property var actions: lockedSession ? allActions.filter(action => action.title !== "Lock" && action.title !== "Sign out") : allActions
    readonly property var allActions: [
        {title: "Lock", subtitle: "Keep everything running", icon: "\ue899", command: [Quickshell.env("HOME") + "/.config/quickshell/lockscreen/lock.sh"], confirm: false},
        {title: "Sleep", subtitle: "Pause and resume quickly", icon: "\ue51c", command: ["systemctl", "suspend"], confirm: false},
        {title: "Sign out", subtitle: "Close your session", icon: "\ue9ba", command: ["hyprctl", "dispatch", "hl.dsp.exit()"], confirm: true, question: "Sign out of your session?", hint: "You can sign back in anytime.", description: "Open apps will close and you'll return to the sign-in screen."},
        {title: "Restart", subtitle: "Close apps and reboot", icon: "\ue5d5", command: ["systemctl", "reboot"], confirm: true, question: "Restart this computer?", hint: "Your session will start again.", description: "All open apps will close. Save your work before restarting."},
        {title: "Shut down", subtitle: "Turn off this computer", icon: "\ue8ac", command: ["systemctl", "poweroff"], confirm: true, question: "Shut down this computer?", hint: "You can turn it back on anytime.", description: "All open apps will close. Save your work before continuing."}
    ]
    implicitWidth: confirming ? 428 : 370
    implicitHeight: form.implicitHeight + 40
    height: implicitHeight
    radius: 18
    color: Colors.bgAlt
    border.width: 1
    border.color: Colors.border
    MouseArea { anchors.fill: parent; onClicked: root.forceActiveFocus() }
    Keys.onEscapePressed: cancel()

    function selectAction(action) {
        if (action.confirm) pendingAction = action
        else execute(action)
    }
    function execute(action) {
        pendingAction = null
        controller.powerOpen = false
        controller.runCommand(action.command)
    }
    function confirm() {
        if (pendingAction !== null) execute(pendingAction)
    }
    function cancel() {
        if (confirming) pendingAction = null
        else controller.powerOpen = false
    }

    ColumnLayout {
        id: form
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: 20
        spacing: root.confirming ? 16 : 12
        RowLayout {
            Layout.fillWidth: true; spacing: 12
            Rectangle {
                visible: root.confirming
                Layout.preferredWidth: 44; Layout.preferredHeight: 44
                radius: 12; color: Qt.alpha(Colors.accent, 0.18)
                Text { anchors.centerIn: parent; text: root.pendingAction ? root.pendingAction.icon : ""; font.family: Colors.iconFontFamily; font.pixelSize: 24; color: Colors.accent }
            }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 5
                CcText { Layout.fillWidth: true; text: root.confirming ? root.pendingAction.question : "Power"; font.pixelSize: root.confirming ? 16 : 21; font.bold: true; wrapMode: Text.Wrap }
                CcText { Layout.fillWidth: true; text: root.confirming ? root.pendingAction.hint : "Choose what happens next"; font.pixelSize: 11; color: Colors.fgAlt; wrapMode: Text.Wrap }
            }
            CcButton { visible: !root.confirming; icon: "\ue5cd"; implicitWidth: 32; implicitHeight: 32; onClicked: root.cancel() }
        }
        ColumnLayout {
            visible: !root.confirming
            Layout.fillWidth: true; spacing: 8
            Repeater {
                model: root.actions
                delegate: CcRow {
                    required property var modelData
                    Layout.fillWidth: true
                    verticalPadding: 12
                    title: modelData.title
                    subtitle: modelData.subtitle
                    icon: modelData.icon
                    iconColor: modelData.title === "Shut down" ? Colors.accent : Colors.fg
                    iconBackgroundColor: modelData.title === "Shut down" ? Qt.alpha(Colors.accent, 0.18) : Colors.surfaceHover
                    titleColor: modelData.title === "Shut down" ? Colors.accent : Colors.fg
                    color: modelData.title === "Shut down" ? Qt.alpha(Colors.accent, 0.12) : Colors.surface
                    onClicked: root.selectAction(modelData)
                }
            }
        }
        CcText { visible: !root.confirming; Layout.fillWidth: true; text: "You'll be asked to confirm before shutting down."; font.pixelSize: 10; color: Colors.fgAlt; wrapMode: Text.Wrap }
        CcText { visible: root.confirming; Layout.fillWidth: true; text: root.pendingAction ? root.pendingAction.description : ""; font.pixelSize: 12; wrapMode: Text.Wrap }
        Rectangle {
            visible: root.confirming
            Layout.fillWidth: true; implicitHeight: 36
            radius: 9; color: Qt.alpha(Colors.accent, 0.08)
            RowLayout {
                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                Text { text: "\ue002"; font.family: Colors.iconFontFamily; font.pixelSize: 17; color: Colors.accent }
                CcText { Layout.fillWidth: true; text: "Unsaved changes may be lost."; font.pixelSize: 11 }
            }
        }
        RowLayout {
            visible: root.confirming
            Layout.fillWidth: true; spacing: 10
            CcButton { Layout.fillWidth: true; Layout.preferredWidth: 0; Layout.minimumWidth: 0; implicitHeight: 40; text: "Cancel"; onClicked: root.cancel() }
            CcButton { Layout.fillWidth: true; Layout.preferredWidth: 0; Layout.minimumWidth: 0; implicitHeight: 40; text: root.pendingAction ? root.pendingAction.title : ""; color: Colors.accent; primary: true; onClicked: root.confirm() }
        }
    }
}
