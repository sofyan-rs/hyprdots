import Quickshell
import QtQuick
import "../core"

Column {
    spacing: 28
    SystemClock { id: clock; precision: SystemClock.Minutes }
    Text {
        text: Qt.formatDateTime(clock.date, "ddd").toUpperCase() + "   /   "
            + Qt.formatDateTime(clock.date, "dd MMMM yyyy").toUpperCase()
        font.family: Colors.fontFamily
        font.pixelSize: 13
        font.bold: true
        font.letterSpacing: 1
        color: Colors.fgMuted
    }
    DotMatrixClock {
        timeText: Qt.formatDateTime(clock.date, "hh:mm")
        dotStep: 14
        dotSize: 10
        glyphGap: 8
        topInset: 0
        width: implicitWidth
        height: implicitHeight
    }
}
