import QtQuick
import "../core"

// Segmented control whose selected pill slides between options.
Rectangle {
    id: root
    // [{ value, label, icon? }]
    property var options: []
    property string current: ""
    property color trackColor: Colors.surface
    signal activated(string value)

    readonly property int gap: 3
    readonly property int count: Math.max(1, options.length)
    readonly property real segmentWidth: (width - gap * 2 - gap * (count - 1)) / count
    readonly property int currentIndex: options.findIndex(o => o.value === current)

    implicitHeight: 36
    radius: 10
    color: trackColor

    Rectangle {
        visible: root.currentIndex >= 0
        x: root.gap + Math.max(0, root.currentIndex) * (root.segmentWidth + root.gap)
        y: root.gap
        width: root.segmentWidth
        height: root.height - root.gap * 2
        radius: 9
        color: Colors.fg
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    }

    Row {
        x: root.gap; y: root.gap
        spacing: root.gap
        Repeater {
            model: root.options
            Item {
                id: segment
                required property var modelData
                readonly property bool selected: root.current === modelData.value
                readonly property color textColor: selected ? Colors.bg : Colors.fg
                width: root.segmentWidth
                height: root.height - root.gap * 2

                Rectangle {
                    anchors.fill: parent; radius: 9
                    color: !segment.selected && mouse.containsMouse ? Colors.surfaceHover : "transparent"
                }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        visible: (segment.modelData.icon || "") !== ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: segment.modelData.icon || ""
                        font.family: Colors.iconFontFamily; font.pixelSize: 19
                        color: segment.textColor
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    CcText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: segment.modelData.label
                        font.pixelSize: 12
                        color: segment.textColor
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activated(segment.modelData.value)
                }
            }
        }
    }
}
