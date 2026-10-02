import QtQuick
import "../core"

Canvas {
    id: root
    property string timeText: "00:00"
    property color ink: Colors.fg
    property real dotStep: 6
    property real dotSize: 3
    property real glyphGap: 4
    property real topInset: 4
    implicitWidth: {
        let result = 0
        for (const character of timeText)
            result += (glyphs[character] || glyphs["0"])[0].length * dotStep + glyphGap
        return Math.max(0, result - glyphGap)
    }
    implicitHeight: topInset + 6 * dotStep + dotSize
    readonly property var glyphs: ({
        "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
        "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
        "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        "5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"],
        "6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"],
        "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"],
        ":": ["00", "00", "10", "00", "10", "00", "00"]
    })
    onTimeTextChanged: requestPaint()
    onInkChanged: requestPaint()
    onDotStepChanged: requestPaint()
    onDotSizeChanged: requestPaint()
    onGlyphGapChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d")
        ctx.clearRect(0, 0, width, height)
        ctx.fillStyle = ink
        let x = 0
        for (const character of timeText) {
            const glyph = glyphs[character] || glyphs["0"]
            for (let row = 0; row < glyph.length; row++) {
                for (let col = 0; col < glyph[row].length; col++) {
                    if (glyph[row][col] === "1")
                        ctx.fillRect(x + col * dotStep, topInset + row * dotStep, dotSize, dotSize)
                }
            }
            x += glyph[0].length * dotStep + glyphGap
        }
    }
}
