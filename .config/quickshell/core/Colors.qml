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
    readonly property int barHeight: 46
    readonly property int popupTopGap: 6

    readonly property string paletteName: "nothing"

    property var palette: ({
        "surface": "#262626",
        "surfaceAlt": "#292929",
        "surfaceHover": "#303030",
        "fgMuted": "#E6E6E6",
        "accentLight": "#FF7770",
        "bg": "#0B0B0B",
        "bgAlt": "#111111",
        "fg": "#F3F3F3",
        "fgAlt": "#969696",
        "accent": "#F15A52",
        "secondary": "#EB514B",
        "border": "#303030",
        "accentText": "#0B0B0B",
        "wsFocusedBg": "#303030",
        "clockBg": "#262626",
        "wallpaperIcon": "#FF7770"
    })

    readonly property color surface: palette.surface
    readonly property color surfaceAlt: palette.surfaceAlt
    readonly property color surfaceHover: palette.surfaceHover
    readonly property color fgMuted: palette.fgMuted
    readonly property color accentLight: palette.accentLight
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
            "surface": "surface",
            "surface-alt": "surfaceAlt",
            "surface-hover": "surfaceHover",
            "fg-muted": "fgMuted",
            "accent-light": "accentLight",

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
