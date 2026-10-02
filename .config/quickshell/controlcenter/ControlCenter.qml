import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth as Bluez
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import QtQuick
import "../core"

PanelWindow {
    id: root
    required property var barScreen
    required property Item triggerItem
    property real rightMargin: 20
    readonly property bool open: PopupManager.activeId === "controlcenter" && PopupManager.activeScreen === barScreen
    property string page: "hub"
    property bool powerOpen: false
    property string tab: "wifi"
    property var pendingNetwork: null
    property var lastNetwork: null
    property var pairingDevice: null
    property string bluetoothMessage: ""
    property string pairingPrompt: ""
    property bool pairingConfirmation: false
    property bool ownsScan: false
    property alias network: net
    readonly property var adapter: Bluez.Bluetooth.defaultAdapter
    readonly property bool bluetoothOn: adapter ? adapter.enabled : false
    readonly property var devices: adapter ? adapter.devices.values : []
    readonly property var connectedDevices: devices.filter(d => d.connected)
    readonly property var nearbyDevices: devices.filter(d => !d.connected)
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property var players: Mpris.players.values.filter(p => p.trackTitle !== "" || p.playbackState !== MprisPlaybackState.Stopped)
    property int playerIndex: 0
    readonly property var player: players.length ? players[Math.min(playerIndex, players.length - 1)] : null
    readonly property var wifi: net.state.current

    screen: barScreen
    // Keep the layer mapped so rapid toggles only reverse the QML animation.
    visible: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins.top: Colors.barHeight + Colors.popupTopGap
    margins.right: rightMargin
    readonly property real desiredHeight: Math.min(content.implicitHeight,
                                                   barScreen ? barScreen.height - Colors.barHeight - 32 : 720)
    property real animatedHeight: 1
    // Coalesce layout recalculations before starting a single resize transition.
    onDesiredHeightChanged: {
        if (open && content && content.opacity > 0.01) resizeTimer.restart()
        else if (open || !visible) resizePanel()
    }
    Component.onCompleted: {
        resizePanel()
        Qt.callLater(updatePopupPosition)
    }
    Timer { id: resizeTimer; interval: 20; onTriggered: root.resizePanel() }
    function resizePanel() { animatedHeight = desiredHeight }
    // The transparent Wayland surface stays stable; only the visible QML card resizes.
    implicitWidth: Math.min(470, barScreen ? barScreen.width - 28 : 470)
    implicitHeight: Math.max(1, barScreen ? barScreen.height - Colors.barHeight - 32 : 720)
    mask: Region {
        x: content.x
        y: content.y
        width: root.open && !root.powerOpen ? content.width : 0
        height: root.open && !root.powerOpen ? content.height : 0
    }
    Behavior on animatedHeight {
        enabled: root.open && content.opacity > 0.01
        NumberAnimation {
            id: heightAnimation
            duration: 180
            easing.type: Easing.OutCubic
        }
    }
    WlrLayershell.namespace: "quickshell-controlcenter"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open && !powerOpen && page === "saved" ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    function updatePopupPosition() {
        const screenW = barScreen ? barScreen.width : 0
        const pos = triggerItem.mapToItem(null, triggerItem.width, 0)
        rightMargin = Math.max(4, screenW - pos.x)
    }
    Connections {
        target: root.triggerItem
        function onXChanged() { Qt.callLater(root.updatePopupPosition) }
        function onWidthChanged() { Qt.callLater(root.updatePopupPosition) }
    }
    function toggle(targetPage, targetTab) {
        const activeHere = PopupManager.activeId === "controlcenter" && PopupManager.activeScreen === barScreen
        const samePanel = page === targetPage && (!targetTab || targetPage !== "connections" || tab === targetTab)
        if (activeHere && samePanel) {
            PopupManager.close()
            return
        }
        page = targetPage
        if (targetTab) tab = targetTab
        powerOpen = false
        if (!activeHere) PopupManager.toggle("controlcenter", barScreen)
    }
    function setVolume(value) { if (sink && sink.audio) { sink.audio.volume = value; sink.audio.muted = false } }
    function toggleMute() { if (sink && sink.audio) sink.audio.muted = !sink.audio.muted }
    function formatTime(value) {
        const seconds = Math.max(0, Math.floor(value || 0))
        return Math.floor(seconds / 60) + ":" + (seconds % 60).toString().padStart(2, "0")
    }
    function pickPlayer() {
        const playing = players.findIndex(p => p.isPlaying)
        playerIndex = playing >= 0 ? playing : 0
    }
    onPlayersChanged: pickPlayer()

    function connectNetwork(entry) {
        if (net.busy || entry.inUse) return
        lastNetwork = entry
        net.error = ""
        const saved = net.state.saved.find(s => entry.uuid ? s.uuid === entry.uuid : s.ssid === entry.ssid)
        if (entry.secured && !saved) {
            pendingNetwork = entry
        } else {
            net.run({ action: "connect", ssid: entry.ssid, device: entry.device || "", uuid: entry.uuid || (saved ? saved.uuid : ""), autojoin: saved ? saved.autojoin : true })
        }
    }
    function submitPassword(password, autojoin) {
        const saved = net.state.saved.find(s => pendingNetwork.uuid ? s.uuid === pendingNetwork.uuid : s.ssid === pendingNetwork.ssid)
        net.run({ action: "connect", ssid: pendingNetwork.ssid, device: pendingNetwork.device || "", uuid: saved ? saved.uuid : "", password: password, autojoin: autojoin })
    }
    function scanBluetooth() {
        if (!adapter || !adapter.enabled) return
        if (!adapter.discovering) { adapter.discovering = true; ownsScan = true }
        scanTimer.restart()
    }
    function updateScan() {
        if (open && page === "connections" && tab === "bluetooth" && bluetoothOn) scanBluetooth()
        else if (ownsScan && adapter) { adapter.discovering = false; ownsScan = false; scanTimer.stop() }
    }
    function connectDevice(device) {
        bluetoothMessage = ""
        if (device.paired) device.connected = true
        else { pairingDevice = device; device.pair() }
    }
    function runCommand(command) {
        actionProc.command = command
        actionProc.running = true
        PopupManager.close()
    }
    onOpenChanged: {
        if (open) { updatePopupPosition(); resizePanel(); net.refresh(); pickPlayer() }
        else { powerOpen = false; pendingNetwork = null; pairingPrompt = ""; if (pairingDevice && pairingDevice.pairing) pairingDevice.cancelPair(); pairingDevice = null }
        updateScan()
    }
    onPageChanged: updateScan()
    onTabChanged: updateScan()
    onBluetoothOnChanged: updateScan()
    Timer { id: scanTimer; interval: 20000; onTriggered: { if (root.ownsScan && root.adapter) root.adapter.discovering = false; root.ownsScan = false } }
    Timer { interval: 1000; running: root.open && root.player !== null && root.player.isPlaying; repeat: true; onTriggered: root.player.positionChanged() }
    PwObjectTracker { objects: [root.sink] }
    NetworkState {
        id: net
        active: root.open
        onActionFinished: (success, action) => {
            if (action === "connect") {
                if (success) { root.pendingNetwork = null; root.lastNetwork = null }
                else if (root.lastNetwork && root.lastNetwork.secured) root.pendingNetwork = root.lastNetwork
            }
        }
    }
    Process { id: actionProc }

    Connections {
        target: root.pairingDevice
        function onPairedChanged() {
            if (root.pairingDevice && root.pairingDevice.paired) {
                root.pairingDevice.trusted = true
                root.pairingDevice.connected = true
                root.pairingPrompt = ""
                root.pairingDevice = null
            }
        }
    }
    Process {
        id: bluetoothAgent
        command: ["bluetoothctl", "--agent", "KeyboardDisplay"]
        stdinEnabled: true
        running: root.open && root.page === "connections" && root.tab === "bluetooth"
        onStarted: write("default-agent\n")
        stdout: SplitParser {
            onRead: line => {
                const clean = line.replace(/\x1b\[[0-9;]*[a-zA-Z]/g, "").trim()
                if (/Confirm passkey|Authorize service|Request confirmation/.test(clean)) {
                    root.pairingPrompt = clean; root.pairingConfirmation = true
                } else if (/Enter PIN|Enter passkey|Request PIN|Request passkey/.test(clean)) {
                    root.pairingPrompt = clean; root.pairingConfirmation = false
                } else if (/Failed|AuthenticationCanceled|AuthenticationFailed/.test(clean)) {
                    root.bluetoothMessage = clean; root.pairingPrompt = ""
                }
            }
        }
    }
    function answerPairing(answer) { bluetoothAgent.write(answer + "\n"); pairingPrompt = "" }

    CenterContent {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: root.animatedHeight
        controller: root
        visible: !root.powerOpen
        enabled: root.open && !root.powerOpen
        clip: true
        opacity: root.open ? 1 : 0
        scale: root.open ? 1 : 0.98
        transformOrigin: Item.TopRight
        transform: Translate {
            y: root.open ? 0 : -6
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        focus: root.open && !root.powerOpen
        Keys.onEscapePressed: PopupManager.close()
    }

    PasswordDialog {
        controller: root
        onSubmitted: (password, autojoin) => root.submitPassword(password, autojoin)
        onCancelled: root.pendingNetwork = null
    }
    PairingDialog { controller: root }
    PowerDialog { controller: root }
}
