import Quickshell
import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    property bool open: false
    property var viewDate: new Date()
    readonly property string todayKey: liveClock.date.toDateString()
    readonly property var dayCells: computeDayCells(viewDate, todayKey)
    readonly property string utcOffset: {
        const offset = -liveClock.date.getTimezoneOffset()
        const hours = Math.floor(Math.abs(offset) / 60).toString().padStart(2, "0")
        const minutes = Math.abs(offset) % 60
        return "UTC" + (offset >= 0 ? "+" : "−") + hours
            + (minutes ? ":" + minutes.toString().padStart(2, "0") : "")
    }

    implicitWidth: 410
    implicitHeight: column.implicitHeight + 40
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

    onOpenChanged: {
        if (open)
            showToday()
    }

    function showToday() {
        viewDate = new Date(liveClock.date.getFullYear(), liveClock.date.getMonth(), 1)
    }

    function shiftMonth(delta) {
        viewDate = new Date(viewDate.getFullYear(), viewDate.getMonth() + delta, 1)
    }

    function computeDayCells(ref, today) {
        const year = ref.getFullYear()
        const month = ref.getMonth()
        const startOffset = new Date(year, month, 1).getDay()
        const daysInMonth = new Date(year, month + 1, 0).getDate()
        const cellCount = Math.max(35, Math.ceil((startOffset + daysInMonth) / 7) * 7)
        const cells = []
        for (let i = 0; i < cellCount; i++) {
            const cellDate = new Date(year, month, i - startOffset + 1)
            cells.push({
                day: cellDate.getDate(),
                inMonth: cellDate.getMonth() === month,
                isToday: cellDate.toDateString() === today
            })
        }
        return cells
    }

    SystemClock {
        id: liveClock
        precision: root.open ? SystemClock.Seconds : SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        radius: 18
        color: Colors.bgAlt
        border.width: 1
        border.color: Colors.border
    }

    ColumnLayout {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20
        spacing: 14

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "DATE & TIME"
                font.family: Colors.fontFamily
                font.pixelSize: 10
                color: Colors.accent
            }

            Item { Layout.fillWidth: true }

            Text {
                text: root.utcOffset
                font.family: Colors.fontFamily
                font.pixelSize: 10
                color: Colors.fgAlt
            }
        }

        DotMatrixClock {
            Layout.preferredWidth: 248
            Layout.preferredHeight: 48
            timeText: Qt.formatDateTime(liveClock.date, "hh:mm:ss")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.maximumWidth: column.width - todayButton.width - 8
                elide: Text.ElideRight
                text: Qt.formatDateTime(liveClock.date, "dddd, d MMMM yyyy")
                font.family: Colors.fontFamily
                font.pixelSize: 13
                color: Colors.fgAlt
            }

            Rectangle {
                id: todayButton
                Layout.preferredWidth: 44
                Layout.preferredHeight: 20
                radius: 5
                color: Qt.alpha(Colors.accent, todayMouse.containsMouse ? 0.22 : 0.12)

                Text {
                    anchors.centerIn: parent
                    text: "TODAY"
                    font.family: Colors.fontFamily
                    font.pixelSize: 9
                    color: Colors.accent
                }

                MouseArea {
                    id: todayMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showToday()
                }
            }

            Item { Layout.fillWidth: true }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Colors.border
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Text {
                Layout.fillWidth: true
                text: Qt.formatDate(root.viewDate, "MMMM yyyy")
                font.family: Colors.fontFamily
                font.pixelSize: 16
                font.bold: true
                color: Colors.fg
            }

            Repeater {
                model: [-1, 1]

                delegate: Rectangle {
                    required property int modelData
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 8
                    color: monthMouse.containsMouse ? Colors.border : Colors.surface

                    Text {
                        anchors.centerIn: parent
                        text: modelData < 0 ? "\ue5cb" : "\ue5cc"
                        font.family: Colors.iconFontFamily
                        font.pixelSize: 20
                        color: Colors.fg
                    }

                    MouseArea {
                        id: monthMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.shiftMonth(parent.modelData)
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 8
            columnSpacing: 4

            Repeater {
                model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

                delegate: Text {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 24
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    font.family: Colors.fontFamily
                    font.pixelSize: 11
                    color: Colors.fgAlt
                }
            }

            Repeater {
                model: root.dayCells

                delegate: Item {
                    id: dayCell
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 34

                    Rectangle {
                        anchors.centerIn: parent
                        width: 34
                        height: 34
                        radius: 17
                        color: dayCell.modelData.isToday ? Colors.accent : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: dayCell.modelData.day
                        font.family: Colors.fontFamily
                        font.pixelSize: 13
                        font.bold: dayCell.modelData.isToday
                        color: dayCell.modelData.isToday ? Colors.accentText : (dayCell.modelData.inMonth ? Colors.fg : Colors.fgAlt)
                        opacity: dayCell.modelData.inMonth || dayCell.modelData.isToday ? 1 : 0.5
                    }
                }
            }
        }
    }
}
