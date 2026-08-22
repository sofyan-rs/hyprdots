import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../core"

Item {
    id: root

    property bool open: false
    signal refreshRequested()

    property bool powered: false
    property bool scanning: false
    property var devices: []

    transformOrigin: Item.TopRight

    implicitWidth: 290
    implicitHeight: column.implicitHeight + 16

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
            refreshAll()
    }

    Process {
        id: powerReadProc
        command: ["sh", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo on || echo off"]
        stdout: SplitParser {
            onRead: line => root.powered = line.trim() === "on"
        }
    }

    Process {
        id: powerToggleProc
        property bool turningOn: false
        command: ["bluetoothctl", "power", turningOn ? "on" : "off"]
        onExited: {
            const wasTurningOn = turningOn
            root.powered = wasTurningOn
            root.devices = []
            root.refreshRequested()
            if (wasTurningOn) {
                root.startScan()
            } else {
                if (scanProc.running)
                    scanProc.running = false
                refreshAll()
            }
        }
    }

    function togglePower() {
        powerToggleProc.turningOn = !root.powered
        powerToggleProc.running = true
    }

    Process {
        id: pairedProc
        command: ["bluetoothctl", "devices", "Paired"]
        property var rows: []
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const m = line.match(/^Device\s+([0-9A-Fa-f:]+)\s+(.+)$/)
                if (m)
                    pairedProc.rows.push({ mac: m[1], name: m[2], paired: true })
            }
        }
        onRunningChanged: {
            if (running)
                rows = []
        }
        onExited: mergeConnected()
    }

    Process {
        id: connectedProc
        command: ["bluetoothctl", "devices", "Connected"]
        property var macs: []
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const m = line.match(/^Device\s+([0-9A-Fa-f:]+)\s+/)
                if (m)
                    connectedProc.macs.push(m[1])
            }
        }
        onRunningChanged: {
            if (running)
                macs = []
        }
        onExited: mergeConnected()
    }

    Process {
        id: allDevicesProc
        command: ["bluetoothctl", "devices"]
        property var rows: []
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const m = line.match(/^Device\s+([0-9A-Fa-f:]+)\s+(.+)$/)
                if (m)
                    allDevicesProc.rows.push({ mac: m[1], name: m[2] })
            }
        }
        onRunningChanged: {
            if (running)
                rows = []
        }
        onExited: mergeConnected()
    }

    function mergeConnected() {
        if (pairedProc.running || connectedProc.running || allDevicesProc.running)
            return
        const pairedSet = {}
        for (const d of pairedProc.rows)
            pairedSet[d.mac] = true
        const connectedSet = {}
        for (const mac of connectedProc.macs)
            connectedSet[mac] = true
        const seen = {}
        const merged = []
        for (const d of pairedProc.rows.concat(allDevicesProc.rows)) {
            if (seen[d.mac])
                continue
            seen[d.mac] = true
            merged.push({
                mac: d.mac,
                name: d.name,
                paired: !!pairedSet[d.mac],
                connected: !!connectedSet[d.mac]
            })
        }
        merged.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired))
        root.devices = merged
    }

    function refreshAll() {
        powerReadProc.running = true
        pairedProc.running = true
        connectedProc.running = true
        allDevicesProc.running = true
    }

    Process {
        id: connectProc
        property string mac: ""
        property bool wasConnected: false
        command: [wasConnected ? "bluetoothctl" : "bluetoothctl", wasConnected ? "disconnect" : "connect", mac]
        onExited: {
            root.refreshRequested()
            refreshAll()
        }
    }

    function toggleConnect(dev) {
        connectProc.mac = dev.mac
        connectProc.wasConnected = dev.connected
        connectProc.running = true
    }

    property string pairingMac: ""

    Process {
        id: pairProc
        property string mac: ""
        command: ["bluetoothctl", "pair", mac]
        onRunningChanged: root.pairingMac = running ? mac : ""
        onExited: {
            root.refreshRequested()
            refreshAll()
        }
    }

    function pairDevice(dev) {
        pairProc.mac = dev.mac
        pairProc.running = true
    }

    function rowClicked(dev) {
        if (dev.paired)
            root.toggleConnect(dev)
        else
            root.pairDevice(dev)
    }

    Process {
        id: scanProc
        command: ["bluetoothctl", "--timeout", "8", "scan", "on"]
        onRunningChanged: root.scanning = running
        onExited: refreshAll()
    }

    function startScan() {
        if (scanProc.running)
            return
        scanProc.running = true
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
        anchors.margins: 8
        spacing: 4

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 36
            radius: Colors.radius
            color: powerArea.containsMouse ? Colors.secondary : "transparent"

            Behavior on color {
                ColorAnimation { duration: 100 }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                Text {
                    text: ""
                    font.family: Colors.iconFontFamily
                    font.pixelSize: Colors.fontSize
                    color: powerArea.containsMouse ? Colors.accentText : Colors.fg
                }

                Text {
                    Layout.fillWidth: true
                    text: "Bluetooth"
                    font.family: Colors.fontFamily
                    font.pixelSize: Colors.fontSize
                    font.bold: true
                    color: powerArea.containsMouse ? Colors.accentText : Colors.fg
                }

                Text {
                    text: root.powered ? "" : ""
                    font.family: Colors.iconFontFamily
                    font.pixelSize: Colors.fontSize + 4
                    color: root.powered ? Colors.accent : Colors.fgAlt
                }
            }

            MouseArea {
                id: powerArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.togglePower()
            }
        }

        Repeater {
            model: root.powered ? root.devices : []

            delegate: Rectangle {
                id: devRow

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: 36
                radius: Colors.radius
                color: devArea.containsMouse ? Colors.secondary : (devRow.modelData.connected ? Colors.bg : "transparent")

                Behavior on color {
                    ColorAnimation { duration: 100 }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        text: devRow.modelData.connected ? "" : ""
                        font.family: Colors.iconFontFamily
                        font.pixelSize: Colors.fontSize
                        color: devArea.containsMouse ? Colors.accentText : Colors.fg
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                        text: devRow.modelData.name
                        font.family: Colors.fontFamily
                        font.pixelSize: Colors.fontSize
                        font.bold: devRow.modelData.connected
                        color: devArea.containsMouse ? Colors.accentText : Colors.fg
                    }

                    Text {
                        visible: root.pairingMac === devRow.modelData.mac
                        text: "\ue627"
                        font.family: Colors.iconFontFamily
                        font.pixelSize: Colors.fontSize - 4
                        color: Colors.fgAlt

                        RotationAnimation on rotation {
                            running: root.pairingMac === devRow.modelData.mac
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 700
                        }
                    }

                    Text {
                        visible: root.pairingMac !== devRow.modelData.mac && !devRow.modelData.paired
                        text: "Pair"
                        font.family: Colors.fontFamily
                        font.pixelSize: Colors.fontSize - 4
                        color: devArea.containsMouse ? Colors.accentText : Colors.fgAlt
                    }

                    Text {
                        visible: root.pairingMac !== devRow.modelData.mac && devRow.modelData.paired && devRow.modelData.connected
                        text: "\ue668"
                        font.family: Colors.iconFontFamily
                        font.pixelSize: Colors.fontSize
                        color: devArea.containsMouse ? Colors.accentText : Colors.accent
                    }
                }

                MouseArea {
                    id: devArea
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.pairingMac === ""
                    onClicked: root.rowClicked(devRow.modelData)
                }
            }
        }

        Rectangle {
            visible: root.powered
            Layout.fillWidth: true
            Layout.topMargin: 2
            implicitHeight: 36
            radius: Colors.radius
            color: scanArea.containsMouse ? Colors.secondary : "transparent"

            Behavior on color {
                ColorAnimation { duration: 100 }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                Text {
                    text: ""
                    font.family: Colors.iconFontFamily
                    font.pixelSize: Colors.fontSize
                    color: scanArea.containsMouse ? Colors.accentText : Colors.fgAlt

                    RotationAnimation on rotation {
                        running: root.scanning
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 900
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.scanning ? "Scanning..." : "Scan for devices"
                    font.family: Colors.fontFamily
                    font.pixelSize: Colors.fontSize
                    color: scanArea.containsMouse ? Colors.accentText : Colors.fgAlt
                }
            }

            MouseArea {
                id: scanArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.scanning
                onClicked: root.startScan()
            }
        }
    }
}
