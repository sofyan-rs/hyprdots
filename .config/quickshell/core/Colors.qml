pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property string fontFamily: "Maple Mono NF"
    readonly property string iconFontFamily: "Material Symbols Rounded"
    readonly property int fontSize: 16
    readonly property int radius: 4
    readonly property int barHeight: 40

    property var palette: ({
        "bg": "#0a0a12",
        "bgAlt": "#161622",
        "fg": "#e8f5f2",
        "fgAlt": "#8f96b8",
        "accent": "#3ee8c8",
        "secondary": "#b569e0",
        "border": "#2a2a42",
        "accentText": "#0a0a12",
        "wsFocusedBg": "#3a2e58",
        "clockBg": "#2a2a42",
        "wallpaperIcon": "#ff6ec7"
    })

    readonly property color bg: palette.bg
    readonly property color bgAlt: palette.bgAlt
    readonly property color fg: palette.fg
    readonly property color fgAlt: palette.fgAlt
    readonly property color accent: palette.accent
    readonly property color secondary: palette.secondary
    readonly property color border: palette.border
    readonly property color accentText: palette.accentText
    readonly property color wsFocusedBg: palette.wsFocusedBg
    readonly property color clockBg: palette.clockBg
    readonly property color wallpaperIcon: palette.wallpaperIcon
    readonly property color shadow: Qt.rgba(0, 0, 0, 0.35)

    function parseColors(content) {
        const keyMap = {
            "bg": "bg",
            "bg-alt": "bgAlt",
            "fg": "fg",
            "fg-alt": "fgAlt",
            "accent": "accent",
            "secondary": "secondary",
            "border": "border",
            "on-accent": "accentText",
            "workspace-focused-bg": "wsFocusedBg",
            "clock-bg": "clockBg",
            "wallpaper-icon": "wallpaperIcon"
        }
        const next = Object.assign({}, root.palette)
        const re = /@define-color\s+([\w-]+)\s+(#[0-9a-fA-F]{3,8}|rgba?\([^)]*\))/g
        let m
        while ((m = re.exec(content)) !== null) {
            const propName = keyMap[m[1]]
            if (propName)
                next[propName] = m[2]
        }
        root.palette = next
    }

    FileView {
        id: colorsFile
        path: Quickshell.env("HOME") + "/.config/theme/quickshell-colors.css"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.parseColors(text())
    }
}
