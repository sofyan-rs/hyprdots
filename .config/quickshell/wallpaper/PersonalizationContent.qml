import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../core"
import "../controlcenter"

Rectangle {
    id: root
    required property var controller
    implicitWidth: 690
    implicitHeight: form.implicitHeight + 40
    radius: 20; color: Colors.bgAlt; border.width: 1; border.color: Colors.border
    Keys.onEscapePressed: controller.done()
    Flickable {
        anchors.fill: parent; anchors.margins: 20
        contentHeight: form.implicitHeight; clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: form
            width: parent.width; spacing: 12
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                CcButton { icon: "\ue5c4"; implicitWidth: 36; onClicked: root.controller.back() }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 5
                    CcText { text: "Personalization"; font.pixelSize: 21; font.bold: true }
                    CcText { text: "Wallpaper and dock, your way"; font.pixelSize: 11; color: Colors.fgAlt }
                }
            }
            ClippingRectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 154; radius: 14; color: Colors.surface
                Image { anchors.fill: parent; source: root.controller.currentPreview ? "file://" + root.controller.currentPreview : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 1300; sourceSize.height: 308 }
                Rectangle { anchors.fill: parent; gradient: Gradient { GradientStop { position: 0; color: "#55000000" } GradientStop { position: 1; color: "#00000000" } } }
                Column {
                    anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 18; spacing: 5
                    CcText { text: "CURRENT · " + root.controller.currentPath.split("/").pop().toUpperCase(); font.pixelSize: 10; color: "#F3F3F3" }
                    CcText { text: root.controller.currentPath ? root.controller.currentPath.split("/").pop().replace(/\.[^.]+$/, "") : "Choose your wallpaper"; font.pixelSize: 15; font.bold: true; color: "#F3F3F3" }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                CcText { text: "YOUR LIBRARY"; font.pixelSize: 10; color: Colors.accent }
                Item { Layout.fillWidth: true }
                CcText { text: root.controller.filtered.length + " images"; font.pixelSize: 10; color: Colors.accent }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 36; radius: 9; color: Colors.surface
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                        Text { text: "\ue8b6"; font.family: Colors.iconFontFamily; font.pixelSize: 18; color: Colors.fgAlt }
                        TextInput {
                            id: search; Layout.fillWidth: true; clip: true; selectByMouse: true
                            text: root.controller.query
                            onTextEdited: root.controller.query = text
                            font.family: Colors.fontFamily; font.pixelSize: 11; color: Colors.fg
                            Text { anchors.fill: parent; visible: !search.text; text: "Search wallpapers..."; font: search.font; color: Colors.fgAlt }
                        }
                    }
                }
                CcButton { icon: "\ue043"; implicitWidth: 36; enabled: !root.controller.busy && root.controller.filtered.length > 1; onClicked: root.controller.shuffle() }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: root.controller.pageImages
                    delegate: ColumnLayout {
                        id: thumb
                        required property var modelData
                        Layout.fillWidth: true; Layout.preferredWidth: 0; spacing: 5
                        readonly property bool current: modelData.path === root.controller.currentPath
                        Item {
                            Layout.fillWidth: true; Layout.preferredHeight: 66
                            ClippingRectangle {
                                anchors.fill: parent; radius: 8; color: Colors.surface
                                Image { anchors.fill: parent; source: "file://" + thumb.modelData.preview; fillMode: Image.PreserveAspectCrop; sourceSize.width: 320; sourceSize.height: 132; asynchronous: true }
                            }
                            Rectangle { anchors.fill: parent; radius: 8; color: "transparent"; border.width: thumb.current ? 2 : 1; border.color: thumb.current ? Colors.accent : Colors.border }
                            Rectangle {
                                visible: thumb.current; width: 20; height: 20; radius: 10; color: Colors.accent
                                anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 8
                                Text { anchors.centerIn: parent; text: "\ue5ca"; font.family: Colors.iconFontFamily; font.pixelSize: 14; color: Colors.fg }
                            }
                            MouseArea { anchors.fill: parent; enabled: !root.controller.busy; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.controller.setWallpaper(thumb.modelData.path) }
                        }
                        CcText { Layout.fillWidth: true; text: thumb.modelData.name; font.pixelSize: 10; font.bold: thumb.current; color: thumb.current ? Colors.fg : Colors.fgAlt }
                    }
                }
                Repeater { model: Math.max(0, 4 - root.controller.pageImages.length); Item { Layout.fillWidth: true; Layout.preferredWidth: 0 } }
            }
            CcEmptyState { visible: root.controller.filtered.length === 0; text: "No wallpapers found"; Layout.fillWidth: true }
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                CcText { text: (root.controller.pageIndex + 1).toString().padStart(2, "0") + " / " + root.controller.pageCount.toString().padStart(2, "0"); font.pixelSize: 10; color: Colors.fgAlt }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 4; radius: 2; color: Colors.border
                    Rectangle { width: parent.width * (root.controller.pageIndex + 1) / root.controller.pageCount; height: parent.height; radius: 2; color: Colors.accent }
                }
                RowLayout {
                    spacing: 6
                    CcButton { icon: "\ue5cb"; implicitWidth: 28; implicitHeight: 28; enabled: root.controller.pageIndex > 0; onClicked: root.controller.pageIndex-- }
                    CcButton { icon: "\ue5cc"; implicitWidth: 28; implicitHeight: 28; primary: true; enabled: root.controller.pageIndex < root.controller.pageCount - 1; onClicked: root.controller.pageIndex++ }
                }
            }
            CcText { visible: root.controller.error !== ""; text: root.controller.error; Layout.fillWidth: true; font.pixelSize: 11; color: Colors.accent; wrapMode: Text.Wrap }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.border }
            RowLayout {
                Layout.fillWidth: true
                CcText { text: "DOCK"; font.pixelSize: 10; color: Colors.accent }
                Item { Layout.fillWidth: true }
                CcText { text: "Appearance & behaviour"; font.pixelSize: 10; color: Colors.fgAlt }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 12
                ColumnLayout {
                    Layout.fillWidth: true; Layout.preferredWidth: 0; spacing: 8
                    CcText { text: "Position"; font.pixelSize: 12 }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 36; radius: 10; color: Colors.surface
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 3; spacing: 3
                            Repeater {
                                model: ["left", "bottom", "right"]
                                CcButton {
                                    required property string modelData
                                    Layout.fillWidth: true; Layout.preferredWidth: 0; Layout.minimumWidth: 0; Layout.fillHeight: true
                                    text: modelData[0].toUpperCase() + modelData.slice(1)
                                    primary: DockState.position === modelData
                                    color: primary ? Colors.fg : "transparent"
                                    onClicked: DockState.position = modelData
                                }
                            }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.preferredWidth: 0; spacing: 14
                    RowLayout { Layout.fillWidth: true; CcText { text: "Show dock"; font.pixelSize: 12 } Item { Layout.fillWidth: true } CcSwitch { checked: DockState.open; onClicked: DockState.toggle(root.controller.screen) } }
                    RowLayout { Layout.fillWidth: true; CcText { text: "Lock dock"; font.pixelSize: 12 } Item { Layout.fillWidth: true } CcSwitch { checked: DockState.positionsLocked; onClicked: DockState.toggleLock() } }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                CcButton { text: "Reset defaults"; onClicked: DockState.resetDefaults() }
                CcButton { text: "Done"; primary: true; implicitWidth: 66; onClicked: root.controller.done() }
            }
        }
    }
}
