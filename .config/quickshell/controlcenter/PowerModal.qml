import QtQuick

Item {
    id: root
    required property var controller
    property bool opened: false
    property bool lockedSession: false
    opacity: opened ? 1 : 0
    visible: opacity > 0
    enabled: opened
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    function focusCard() { card.forceActiveFocus() }
    onOpenedChanged: {
        if (opened) {
            card.pendingAction = null
            Qt.callLater(root.focusCard)
        }
    }
    Rectangle { anchors.fill: parent; color: "#99000000" }
    MouseArea { anchors.fill: parent; onClicked: card.cancel() }
    PowerCard {
        id: card
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width - 40)
        controller: root.controller
        lockedSession: root.lockedSession
        scale: root.opened ? 1 : 0.96
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }
}
