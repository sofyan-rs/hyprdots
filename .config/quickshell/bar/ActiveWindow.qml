import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../core"

Text {
    text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : ""
    elide: Text.ElideRight
    Layout.maximumWidth: 500
    font.family: Colors.fontFamily
    font.pixelSize: Colors.fontSize
        font.bold: true
    color: Colors.fg
}
