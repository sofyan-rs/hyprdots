import Quickshell
import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    property bool open: false
    property var viewDate: new Date()
    readonly property var dayCells: computeDayCells(viewDate)

    implicitWidth: 260
    implicitHeight: column.implicitHeight + 32

    transformOrigin: Item.TopRight

    opacity: open ? 1 : 0
    scale: open ? 1 : 0.92
    y: open ? 0 : -14

    Behavior on opacity {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
    Behavior on scale {
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }
    Behavior on y {
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    function shiftMonth(delta) {
        const d = new Date(viewDate)
        d.setMonth(d.getMonth() + delta)
        viewDate = d
    }

    function computeDayCells(ref) {
        const year = ref.getFullYear()
        const month = ref.getMonth()
        const firstOfMonth = new Date(year, month, 1)
        const startOffset = firstOfMonth.getDay()
        const today = new Date()
        const cells = []
        for (let i = 0; i < 42; i++) {
            const dayNum = i - startOffset + 1
            const cellDate = new Date(year, month, dayNum)
            cells.push({
                day: cellDate.getDate(),
                inMonth: cellDate.getMonth() === month,
                isToday: cellDate.toDateString() === today.toDateString()
            })
        }
        return cells
    }

    Rectangle {
        anchors.fill: parent
        radius: Colors.radius
        color: Colors.bgAlt
        border.width: 1
        border.color: Colors.border
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        SystemClock {
            id: liveClock
            precision: SystemClock.Seconds
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(liveClock.date, "hh:mm:ss")
            font.family: Colors.fontFamily
            font.pixelSize: 30
            font.bold: true
            color: Colors.fg
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(liveClock.date, "dddd, dd MMMM yyyy")
            font.family: Colors.fontFamily
            font.pixelSize: Colors.fontSize
            color: Colors.fgAlt
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Colors.border
        }

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "\ue5cb"
                font.family: Colors.iconFontFamily
                font.pixelSize: Colors.fontSize
                color: Colors.fg

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.shiftMonth(-1)
                }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Qt.formatDate(root.viewDate, "MMMM yyyy")
                font.family: Colors.fontFamily
                font.pixelSize: Colors.fontSize
                font.bold: true
                color: Colors.fg
            }

            Text {
                text: "\ue5cc"
                font.family: Colors.iconFontFamily
                font.pixelSize: Colors.fontSize
                color: Colors.fg

                MouseArea {
                    anchors.fill: parent
                    onClicked: root.shiftMonth(1)
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 4
            columnSpacing: 4

            Repeater {
                model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

                delegate: Text {
                    required property string modelData
                    Layout.preferredWidth: 30
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    font.family: Colors.fontFamily
                    font.pixelSize: 12
                    font.bold: true
                    color: Colors.fgAlt
                }
            }

            Repeater {
                model: root.dayCells

                delegate: Rectangle {
                    id: dayCell

                    required property var modelData

                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: width / 2
                    color: modelData.isToday ? Colors.secondary : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: dayCell.modelData.day
                        font.family: Colors.fontFamily
                        font.pixelSize: 13
                        font.bold: dayCell.modelData.isToday
                        color: dayCell.modelData.isToday ? Colors.accentText : (dayCell.modelData.inMonth ? Colors.fg : Colors.fgAlt)
                    }
                }
            }
        }
    }
}
