import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "../core"

Item {
    id: root

    property bool open: false
    signal refreshRequested()

    property bool radioOn: true
    property var networks: []
    property string pendingSsid: ""
    property string errorText: ""
    property var savedConnections: ({})
    property string expandedSsid: ""
    property string connectingSsid: ""
    property var deviceInfo: ({ ip: "", gateway: "", rate: "" })

    transformOrigin: Item.TopRight

    implicitWidth: 280
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
        if (open) {
            pendingSsid = ""
            expandedSsid = ""
            errorText = ""
            rescan()
        }
    }

    Process {
        id: radioToggleProc
        property bool turningOn: false
        command: turningOn
            ? ["sh", "-c", "nmcli radio wifi on; for i in $(seq 1 20); do nmcli device wifi rescan >/dev/null 2>&1 && exit 0; sleep 0.3; done"]
            : ["nmcli", "radio", "wifi", "off"]
        onExited: {
            const wasTurningOn = turningOn
            root.radioOn = wasTurningOn
            root.networks = []
            root.refreshRequested()
            if (wasTurningOn) {
                listProc.retries = 0
                listTimer.start()
            } else {
                root.networks = []
            }
        }
    }

    function toggleRadio() {
        radioToggleProc.turningOn = !root.radioOn
        radioToggleProc.running = true
    }

    Process {
        id: radioReadProc
        command: ["nmcli", "radio", "wifi"]
        stdout: SplitParser {
            onRead: line => root.radioOn = line.trim() === "enabled"
        }
    }

    Process {
        id: rescanProc
        property int retries: 0
        command: ["nmcli", "device", "wifi", "rescan"]
        onExited: exitCode => {
            if (exitCode !== 0 && rescanProc.retries < 10) {
                rescanProc.retries++
                rescanRetryTimer.start()
            } else {
                rescanProc.retries = 0
                listTimer.start()
            }
        }
    }

    Timer {
        id: rescanRetryTimer
        interval: 400
        onTriggered: rescanProc.running = true
    }

    Timer {
        id: listTimer
        interval: 400
        onTriggered: listProc.running = true
    }

    Process {
        id: listProc
        property int retries: 0
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY,DEVICE", "device", "wifi", "list"]
        property var rows: []
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line.trim() === "")
                    return
                const parts = line.split(":")
                if (parts.length < 5)
                    return
                const ssid = parts[1]
                if (ssid === "")
                    return
                listProc.rows.push({
                    inUse: parts[0] === "*",
                    ssid: ssid,
                    signal: parseInt(parts[2], 10) || 0,
                    secured: parts[3] !== "",
                    securityLabel: parts[3] !== "" ? parts[3] : "Open",
                    device: parts[4]
                })
            }
        }
        onRunningChanged: {
            if (running)
                rows = []
        }
        onExited: {
            const seen = {}
            const deduped = []
            for (const row of rows) {
                if (seen[row.ssid])
                    continue
                seen[row.ssid] = true
                deduped.push(row)
            }
            deduped.sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal))
            if (deduped.length === 0 && root.radioOn && listProc.retries < 6) {
                listProc.retries++
                listRetryTimer.start()
            } else {
                listProc.retries = 0
                root.networks = deduped
            }
        }
    }

    Timer {
        id: listRetryTimer
        interval: 500
        onTriggered: listProc.running = true
    }

    Process {
        id: savedConnProc
        command: ["nmcli", "-t", "-f", "NAME", "connection", "show"]
        property var names: ({})
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line.trim() !== "")
                    savedConnProc.names[line.trim()] = true
            }
        }
        onRunningChanged: {
            if (running)
                names = {}
        }
        onExited: root.savedConnections = names
    }

    function rescan() {
        radioReadProc.running = true
        savedConnProc.running = true
        if (!root.radioOn) {
            root.networks = []
            return
        }
        rescanProc.retries = 0
        rescanProc.running = true
    }

    function signalIcon(sig) {
        if (sig >= 80)
            return "\uf065"
        if (sig >= 55)
            return "\uebe1"
        if (sig >= 30)
            return "\uebd6"
        return "\uf0b0"
    }

    property int attemptGen: 0

    Process {
        id: connectProc
        property string ssid: ""
        property string password: ""
        property bool secured: false
        property int gen: 0
        command: password ? ["nmcli", "device", "wifi", "connect", ssid, "password", password]
                           : ["nmcli", "device", "wifi", "connect", ssid]
        stderr: SplitParser {
            onRead: line => {
                if (line.trim() !== "" && connectProc.gen === root.attemptGen)
                    root.errorText = line.trim()
            }
        }
        onExited: exitCode => {
            if (root.connectingSsid === connectProc.ssid)
                root.connectingSsid = ""
            if (connectProc.gen !== root.attemptGen)
                return
            if (exitCode === 0) {
                root.errorText = ""
                root.pendingSsid = ""
                root.refreshRequested()
                rescan()
            } else if (connectProc.secured) {
                if (connectProc.password === "") {
                    staleProfileCleanupProc.ssid = connectProc.ssid
                    staleProfileCleanupProc.running = true
                }
                root.pendingSsid = connectProc.ssid
            }
        }
    }

    Process {
        id: staleProfileCleanupProc
        property string ssid: ""
        command: ["nmcli", "connection", "delete", ssid]
        onExited: savedConnProc.running = true
    }

    Process {
        id: disconnectProc
        property string device: ""
        command: ["nmcli", "device", "disconnect", device]
        onExited: {
            root.refreshRequested()
            rescan()
        }
    }

    Process {
        id: forgetProc
        property string ssid: ""
        command: ["nmcli", "connection", "delete", ssid]
        onExited: {
            root.pendingSsid = ""
            root.errorText = ""
            root.refreshRequested()
            rescan()
        }
    }

    function connectTo(net, password) {
        root.attemptGen++
        root.errorText = ""
        if (net.inUse) {
            disconnectProc.device = net.device
            disconnectProc.running = true
            return
        }
        if (net.secured && !password && !root.savedConnections[net.ssid]) {
            root.pendingSsid = net.ssid
            return
        }
        connectProc.ssid = net.ssid
        connectProc.secured = net.secured
        connectProc.password = password || ""
        connectProc.gen = root.attemptGen
        connectProc.running = true
        root.connectingSsid = net.ssid
    }

    function forget(net) {
        forgetProc.ssid = net.ssid
        forgetProc.running = true
    }

    Process {
        id: deviceInfoProc
        property string device: ""
        command: ["nmcli", "-t", "-f", "IP4.ADDRESS,IP4.GATEWAY", "device", "show", device]
        property var info: ({ ip: "", gateway: "" })
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (line.startsWith("IP4.ADDRESS"))
                    deviceInfoProc.info.ip = line.substring(line.indexOf(":") + 1)
                else if (line.startsWith("IP4.GATEWAY"))
                    deviceInfoProc.info.gateway = line.substring(line.indexOf(":") + 1)
            }
        }
        onRunningChanged: {
            if (running)
                info = { ip: "", gateway: "" }
        }
        onExited: root.deviceInfo = { ip: info.ip, gateway: info.gateway, rate: root.deviceInfo.rate }
    }

    Process {
        id: rateProc
        command: ["sh", "-c", "nmcli -t -f ACTIVE,RATE dev wifi list | grep '^yes:' | head -1 | cut -d: -f2"]
        stdout: SplitParser {
            onRead: line => root.deviceInfo = { ip: root.deviceInfo.ip, gateway: root.deviceInfo.gateway, rate: line.trim() }
        }
    }

    function toggleExpanded(net) {
        if (root.expandedSsid === net.ssid) {
            root.expandedSsid = ""
            return
        }
        root.expandedSsid = net.ssid
        root.deviceInfo = { ip: "", gateway: "", rate: "" }
        deviceInfoProc.device = net.device
        deviceInfoProc.running = true
        rateProc.running = true
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
            color: wifiToggleArea.containsMouse ? Colors.secondary : "transparent"

            Behavior on color {
                ColorAnimation { duration: 100 }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                Text {
                    text: "\ue63e"
                    font.family: Colors.iconFontFamily
                    font.pixelSize: Colors.fontSize
                    color: wifiToggleArea.containsMouse ? Colors.accentText : Colors.fg
                }

                Text {
                    Layout.fillWidth: true
                    text: "Wi-Fi"
                    font.family: Colors.fontFamily
                    font.pixelSize: Colors.fontSize
                    font.bold: true
                    color: wifiToggleArea.containsMouse ? Colors.accentText : Colors.fg
                }

                Text {
                    text: root.radioOn ? "\ue9f6" : "\ue9f5"
                    font.family: Colors.iconFontFamily
                    font.pixelSize: Colors.fontSize + 4
                    color: root.radioOn ? Colors.accent : Colors.fgAlt
                }
            }

            MouseArea {
                id: wifiToggleArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.toggleRadio()
            }
        }

        Text {
            visible: root.errorText !== ""
            Layout.fillWidth: true
            Layout.leftMargin: 10
            text: root.errorText
            font.family: Colors.fontFamily
            font.pixelSize: Colors.fontSize - 2
            color: "#f0454c"
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.radioOn ? root.networks : []

            delegate: ColumnLayout {
                id: netCol

                required property var modelData

                Layout.fillWidth: true
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: Colors.radius
                    color: netArea.containsMouse ? Colors.secondary : (netCol.modelData.inUse ? Colors.bg : "transparent")

                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 10

                        Text {
                            text: root.signalIcon(netCol.modelData.signal)
                            font.family: Colors.iconFontFamily
                            font.pixelSize: Colors.fontSize
                            color: netArea.containsMouse ? Colors.accentText : Colors.fg
                        }

                        Text {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignLeft
                            elide: Text.ElideRight
                            text: netCol.modelData.ssid
                            font.family: Colors.fontFamily
                            font.pixelSize: Colors.fontSize
                            font.bold: netCol.modelData.inUse
                            color: netArea.containsMouse ? Colors.accentText : Colors.fg
                        }

                        Text {
                            visible: netCol.modelData.secured
                            text: "\ue899"
                            font.family: Colors.iconFontFamily
                            font.pixelSize: Colors.fontSize - 4
                            color: netArea.containsMouse ? Colors.accentText : Colors.fgAlt
                        }

                        Text {
                            visible: root.connectingSsid === netCol.modelData.ssid
                            text: "\ue5d5"
                            font.family: Colors.iconFontFamily
                            font.pixelSize: Colors.fontSize
                            color: Colors.accent

                            RotationAnimation on rotation {
                                running: root.connectingSsid === netCol.modelData.ssid
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 700
                            }
                        }

                        Text {
                            visible: root.connectingSsid !== netCol.modelData.ssid
                            text: netCol.modelData.inUse ? (root.expandedSsid === netCol.modelData.ssid ? "\ue5ce" : "\ue5cf") : "\ue5cc"
                            font.family: Colors.iconFontFamily
                            font.pixelSize: Colors.fontSize
                            color: netArea.containsMouse ? Colors.accentText : (netCol.modelData.inUse ? Colors.accent : Colors.fgAlt)
                        }
                    }

                    MouseArea {
                        id: netArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (root.connectingSsid === netCol.modelData.ssid)
                                return
                            if (netCol.modelData.inUse)
                                root.toggleExpanded(netCol.modelData)
                            else
                                root.connectTo(netCol.modelData, passwordField.text)
                        }
                    }
                }

                ColumnLayout {
                    visible: netCol.modelData.inUse && root.expandedSsid === netCol.modelData.ssid
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.topMargin: 6
                    Layout.bottomMargin: 6
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "IP address"; font.family: Colors.fontFamily; font.pixelSize: Colors.fontSize - 4; color: Colors.fgAlt }
                        Item { Layout.fillWidth: true }
                        Text { text: root.deviceInfo.ip || "\u2014"; font.family: Colors.fontFamily; font.pixelSize: Colors.fontSize - 4; color: Colors.fg }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Gateway"; font.family: Colors.fontFamily; font.pixelSize: Colors.fontSize - 4; color: Colors.fgAlt }
                        Item { Layout.fillWidth: true }
                        Text { text: root.deviceInfo.gateway || "\u2014"; font.family: Colors.fontFamily; font.pixelSize: Colors.fontSize - 4; color: Colors.fg }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Security"; font.family: Colors.fontFamily; font.pixelSize: Colors.fontSize - 4; color: Colors.fgAlt }
                        Item { Layout.fillWidth: true }
                        Text { text: netCol.modelData.securityLabel; font.family: Colors.fontFamily; font.pixelSize: Colors.fontSize - 4; color: Colors.fg }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Link speed"; font.family: Colors.fontFamily; font.pixelSize: Colors.fontSize - 4; color: Colors.fgAlt }
                        Item { Layout.fillWidth: true }
                        Text { text: root.deviceInfo.rate ? (root.deviceInfo.rate + " Mbit/s") : "\u2014"; font.family: Colors.fontFamily; font.pixelSize: Colors.fontSize - 4; color: Colors.fg }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 6

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: Colors.radius
                            color: forgetExpArea.containsMouse ? Colors.border : "transparent"
                            border.width: 1
                            border.color: Colors.border

                            Text {
                                anchors.centerIn: parent
                                text: "Forget"
                                font.family: Colors.fontFamily
                                font.pixelSize: Colors.fontSize - 4
                                color: Colors.fg
                            }

                            MouseArea {
                                id: forgetExpArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.expandedSsid = ""
                                    root.forget(netCol.modelData)
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 28
                            radius: Colors.radius
                            color: disconnectExpArea.containsMouse ? Colors.secondary : Colors.bg
                            border.width: 1
                            border.color: "#f0454c"

                            Text {
                                anchors.centerIn: parent
                                text: "Disconnect"
                                font.family: Colors.fontFamily
                                font.pixelSize: Colors.fontSize - 4
                                color: "#f0454c"
                            }

                            MouseArea {
                                id: disconnectExpArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.expandedSsid = ""
                                    root.connectTo(netCol.modelData, "")
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    id: passwordRow
                    visible: root.pendingSsid === netCol.modelData.ssid
                    Layout.fillWidth: true
                    Layout.leftMargin: 10
                    Layout.rightMargin: 10
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    spacing: 6

                    onVisibleChanged: {
                        if (visible)
                            Qt.callLater(() => passwordField.forceActiveFocus())
                    }

                    TextField {
                        id: passwordField
                        Layout.fillWidth: true
                        echoMode: TextInput.Password
                        placeholderText: "Password"
                        color: Colors.fg
                        font.family: Colors.fontFamily
                        font.pixelSize: Colors.fontSize - 2
                        background: Rectangle {
                            radius: Colors.radius
                            color: Colors.bg
                            border.width: 1
                            border.color: Colors.border
                        }
                        onAccepted: root.connectTo(netCol.modelData, passwordField.text)
                    }

                    Text {
                        visible: !!root.savedConnections[netCol.modelData.ssid]
                        text: "\ue92e"
                        font.family: Colors.iconFontFamily
                        font.pixelSize: Colors.fontSize - 4
                        color: forgetRetryArea.containsMouse ? "#f0454c" : Colors.fgAlt
                        MouseArea {
                            id: forgetRetryArea
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            onClicked: root.forget(netCol.modelData)
                        }
                    }

                    Text {
                        text: "\ue668"
                        font.family: Colors.iconFontFamily
                        font.pixelSize: Colors.fontSize
                        color: Colors.accent
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            onClicked: root.connectTo(netCol.modelData, passwordField.text)
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: root.radioOn
            Layout.fillWidth: true
            Layout.topMargin: 2
            implicitHeight: 36
            radius: Colors.radius
            color: refreshArea.containsMouse ? Colors.secondary : "transparent"

            Behavior on color {
                ColorAnimation { duration: 100 }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                Text {
                    id: refreshIcon
                    text: "\ue5d5"
                    font.family: Colors.iconFontFamily
                    font.pixelSize: Colors.fontSize
                    color: refreshArea.containsMouse ? Colors.accentText : Colors.fgAlt

                    RotationAnimation on rotation {
                        running: rescanProc.running || rescanRetryTimer.running || listTimer.running || listProc.running || listRetryTimer.running || radioToggleProc.running
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 700
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Refresh"
                    font.family: Colors.fontFamily
                    font.pixelSize: Colors.fontSize
                    color: refreshArea.containsMouse ? Colors.accentText : Colors.fgAlt
                }
            }

            MouseArea {
                id: refreshArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.rescan()
            }
        }
    }
}
