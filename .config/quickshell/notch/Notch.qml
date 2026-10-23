import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import QtQuick.Effects
import "../core"
import "../aiusage"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property bool island: NotchState.style === "island"
    readonly property var player: NotchState.player
    readonly property bool playing: player !== null && player.isPlaying
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property var monitor: Hyprland.monitorFor(modelData)
    readonly property bool fullscreen: monitor && monitor.activeWorkspace ? monitor.activeWorkspace.hasFullscreen : false

    property bool expanded: false
    // Calendar is the first tab, so it is also where the notch starts after a restart.
    property string tab: "calendar"
    readonly property var tabs: ["calendar", "media", "shelf", "system", "ai"]
    // Pages left of the current tab slide out to the left, the rest to the right.
    // Calendar: the month on screen and the picked day; both reset to today on open.
    property var today: new Date()
    // Clock for the collapsed notch, ticking on the minute.
    property var now: new Date()
    Timer {
        running: root.visible
        interval: 1000; repeat: true
        onTriggered: { const d = new Date(); if (d.getMinutes() !== root.now.getMinutes()) root.now = d }
    }
    property var calendarMonth: new Date(today.getFullYear(), today.getMonth(), 1)
    property var selectedDay: today
    readonly property int firstDayOfWeek: Qt.locale().firstDayOfWeek
    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
    }
    function shiftMonth(n) {
        calendarMonth = new Date(calendarMonth.getFullYear(), calendarMonth.getMonth() + n, 1)
    }
    function resetCalendar() {
        today = new Date()
        calendarMonth = new Date(today.getFullYear(), today.getMonth(), 1)
        selectedDay = today
    }
    // Six full weeks around the month, starting on the locale's first weekday.
    readonly property var calendarDays: {
        const y = calendarMonth.getFullYear(), m = calendarMonth.getMonth()
        const offset = (new Date(y, m, 1).getDay() - firstDayOfWeek + 7) % 7
        const days = []
        for (let i = 0; i < 42; i++) days.push(new Date(y, m, 1 - offset + i))
        return days
    }
    Timer {
        running: root.expanded && root.tab === "calendar"
        interval: 60000; repeat: true
        onTriggered: root.today = new Date()
    }

    function slideOffset(tabId) {
        const i = tabs.indexOf(tabId), current = tabs.indexOf(tab)
        return i === current ? 0 : (i < current ? -28 : 28)
    }
    // Set while a shelf item is being dragged out, so the notch stays open.
    property bool draggingOut: false
    readonly property bool viewingSystem: visible && expanded && tab === "system"
    onViewingSystemChanged: NotchState.systemViewers += viewingSystem ? 1 : -1
    Component.onDestruction: if (viewingSystem) NotchState.systemViewers -= 1
    readonly property var sys: NotchState.system
    readonly property bool romajiOn: NotchState.lyricsRomaji && NotchState.lyricsHasRomaji
    readonly property int lyricRowHeight: romajiOn ? 36 : 25
    readonly property bool showLyrics: player !== null && ["synced", "plain", "instrumental"].includes(NotchState.lyricsStatus)
    // The collapsed notch swaps its clock for the sung line when the toggle is on.
    readonly property bool idleLyric: NotchState.lyricsInNotch && playing && NotchState.currentLyric !== ""
    // Room for indicators on the right of the collapsed notch, mirrored on the left to keep the clock centred.
    readonly property int idleExtras: (NotchState.capsLock ? 26 : 0) + (CaffeineState.active ? 25 : 0)
        + (NotchState.privacyActive ? 8 + 11 * (Number(NotchState.privacy.mic.length > 0) + Number(NotchState.privacy.camera.length > 0) + Number(NotchState.privacy.screen.length > 0)) : 0)
    onExpandedChanged: if (expanded && tab === "calendar") resetCalendar()
    onTabChanged: {
        if (tab === "ai") UsageState.refreshStale()
        if (tab === "calendar") resetCalendar()
    }
    readonly property string mode: expanded ? "expanded" : (NotchState.peekKind !== "" ? "peek" : "idle")

    readonly property color ink: "#000000"
    readonly property color text1: "#F3F3F3"
    readonly property color text2: "#969696"

    visible: NotchState.enabled && !fullscreen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    anchors.top: true
    implicitWidth: 560
    // Tallest page (media with lyrics) plus room for the expand overshoot.
    implicitHeight: 390
    WlrLayershell.namespace: "quickshell-notch"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Only the visible notch takes input; the rest of the surface clicks through.
    mask: Region { x: shell.x; y: shell.y; width: body.width; height: body.height }

    PwObjectTracker { objects: [root.sink] }

    Connections {
        target: NotchState
        function onExpandToggleRequested() {
            collapseTimer.stop()
            root.expanded = !root.expanded
        }
        function onCollapseRequested() {
            collapseTimer.stop()
            root.expanded = false
        }
        function onTabRequested(tab) {
            if (!root.tabs.includes(tab)) return
            collapseTimer.stop()
            root.tab = tab
            root.expanded = true
        }
    }

    Timer {
        id: collapseTimer
        interval: 320
        onTriggered: {
            interval = 320
            if (!root.draggingOut && !hover.hovered && !dropArea.containsDrag) root.expanded = false
        }
    }
    Timer {
        // MPRIS does not push position updates.
        running: root.expanded && root.playing
        interval: 1000
        repeat: true
        onTriggered: if (root.player) root.player.positionChanged()
    }

    // Expanded height that fits a page of the given height under the header.
    function fitHeight(pageHeight) {
        return expandedColumn.anchors.topMargin + headerRow.implicitHeight + expandedColumn.spacing + pageHeight + expandedColumn.anchors.bottomMargin
    }

    function setVolume(v) {
        if (!root.sink || !root.sink.audio) return
        root.sink.audio.volume = Math.max(0, Math.min(1, v))
        root.sink.audio.muted = false
    }

    function formatBytes(b) {
        const units = ["B", "KB", "MB", "GB", "TB"]
        let i = 0
        while (b >= 1024 && i < units.length - 1) { b /= 1024; i++ }
        return (i >= 2 ? b.toFixed(1) : Math.round(b)) + " " + units[i]
    }

    function formatTime(s) {
        s = Math.max(0, Math.floor(s))
        return Math.floor(s / 60) + ":" + (s % 60).toString().padStart(2, "0")
    }

    Item {
        id: shell
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.island ? 6 : 0
        width: body.width
        height: body.height

        // Concave "ears" that blend the notch into the top edge.
        Shape {
            visible: !root.island
            x: -12; y: 0; width: 12; height: 12
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: root.ink; strokeWidth: -1
                startX: 0; startY: 0
                PathLine { x: 12; y: 0 }
                PathLine { x: 12; y: 12 }
                PathArc { x: 0; y: 0; radiusX: 12; radiusY: 12; direction: PathArc.Counterclockwise }
            }
        }
        Shape {
            visible: !root.island
            x: body.width; y: 0; width: 12; height: 12
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: root.ink; strokeWidth: -1
                startX: 12; startY: 0
                PathLine { x: 0; y: 0 }
                PathLine { x: 0; y: 12 }
                PathArc { x: 12; y: 0; radiusX: 12; radiusY: 12; direction: PathArc.Clockwise }
            }
        }

        Rectangle {
            id: body
            property real cornerRadius: root.mode === "expanded" ? 26 : (root.island ? height / 2 : 12)
            width: root.mode === "expanded" ? 480 : (root.mode === "peek" ? (NotchState.peekKind === "caps" ? 240 : NotchState.peekKind === "color" ? 250 : 370) : (root.idleLyric ? 400 : root.playing ? 250 : 210) + 2 * root.idleExtras)
            height: root.mode === "expanded" ? (root.tab === "system" ? 240 : root.tab === "ai" ? root.fitHeight(aiPage.implicitHeight) : root.tab === "calendar" ? root.fitHeight(calendarPage.implicitHeight) : root.tab === "media" && !root.player ? root.fitHeight(84) : root.tab === "media" && root.showLyrics ? 176 + lyricsArea.height + 10 : root.tab === "shelf" ? 160 : 176) : 34
            color: root.ink
            clip: true
            topLeftRadius: root.island ? cornerRadius : 0
            topRightRadius: root.island ? cornerRadius : 0
            bottomLeftRadius: cornerRadius
            bottomRightRadius: cornerRadius
            border.width: root.island ? 1 : 0
            border.color: "#1c1c1c"

            Behavior on width { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
            Behavior on height { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
            Behavior on cornerRadius { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            // Scroll scrolls the shelf on the Shelf tab, and changes the volume everywhere else.
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (root.mode === "expanded" && root.tab === "media" && NotchState.lyricsStatus === "plain" && lyricsHover.hovered) {
                        const maxY = Math.max(0, plainLyricsList.contentHeight - plainLyricsList.height)
                        plainLyricsList.contentY = Math.max(0, Math.min(maxY, plainLyricsList.contentY - event.angleDelta.y / 2))
                        return
                    }
                    if (root.mode === "expanded" && root.tab === "calendar") {
                        const d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
                        if (d !== 0) root.shiftMonth(d > 0 ? -1 : 1)
                        return
                    }
                    if (root.mode === "expanded" && root.tab === "shelf") {
                        const delta = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y
                        const maxX = Math.max(0, shelfList.contentWidth - shelfList.width)
                        shelfList.contentX = Math.max(0, Math.min(maxX, shelfList.contentX - delta))
                        return
                    }
                    const step = event.angleDelta.y / 120 * 0.05
                    if (step === 0) return
                    root.setVolume(root.volume + step)
                    if (root.mode !== "expanded" && NotchState.volumeOsd) NotchState.peek("volume")
                }
            }
            HoverHandler {
                id: hover
                onHoveredChanged: {
                    if (hovered) {
                        collapseTimer.stop()
                        if (NotchState.expandOnHover) root.expanded = true
                    } else {
                        collapseTimer.restart()
                    }
                }
            }
            TapHandler {
                enabled: !NotchState.expandOnHover && root.mode !== "expanded"
                onTapped: root.expanded = true
            }
            DropArea {
                id: dropArea
                anchors.fill: parent
                onEntered: drag => {
                    if ((!drag.hasUrls && !drag.hasText) || root.draggingOut) { drag.accepted = false; return }
                    collapseTimer.stop()
                    root.tab = "shelf"
                    root.expanded = true
                }
                onExited: collapseTimer.restart()
                onDropped: drop => {
                    if (drop.hasUrls) NotchState.addFiles(drop.urls)
                    else if (drop.hasText) NotchState.addText(drop.text)
                    else return
                    drop.acceptProposedAction()
                    // The pointer has not "entered" yet after a drop, so give it time.
                    collapseTimer.interval = 1500
                    collapseTimer.restart()
                }
            }

            // Idle: date and time pinned to the centre; cover on the left, indicators on the right.
            Item {
                anchors.fill: parent
                anchors.leftMargin: 14; anchors.rightMargin: 14
                opacity: root.mode === "idle" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                ClippingRectangle {
                    visible: root.playing
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    width: 20; height: 20; radius: 5; color: "#1a1a1a"
                    // Music icon when the player has no cover art.
                    Text { visible: idleArt.status !== Image.Ready; anchors.centerIn: parent; text: "\ue405"; font.family: Colors.iconFontFamily; font.pixelSize: 14; color: root.text2 }
                    Image { id: idleArt; anchors.fill: parent; source: root.player ? root.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 64; sourceSize.height: 64 }
                }
                Marquee {
                    anchors.centerIn: parent
                    // Only lyrics scroll; the clock always fits.
                    scrolling: root.idleLyric
                    // Room for whatever sits on the sides (cover on the left, indicators on the right), mirrored to stay centred.
                    width: parent.width - 2 * Math.max(root.playing ? 28 : 0, idleIndicators.width > 0 ? idleIndicators.width + 8 : 0)
                    text: root.idleLyric ? NotchState.currentLyric : Qt.formatDateTime(root.now, root.playing ? "hh:mm" : "ddd dd MMM  hh:mm")
                    font.family: Colors.fontFamily; font.pixelSize: root.idleLyric ? 12 : 13; font.bold: true
                    color: root.text1
                }
                Row {
                    id: idleIndicators
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Meter { visible: root.playing; active: root.playing; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        visible: CaffeineState.active
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uefef"
                        font.family: Colors.iconFontFamily; font.pixelSize: 17
                        color: Colors.accent
                    }
                    Text {
                        visible: NotchState.capsLock
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\ue318"
                        font.family: Colors.iconFontFamily; font.pixelSize: 18
                        color: Colors.accent
                    }
                    PrivacyDots { anchors.verticalCenter: parent.verticalCenter }
                }
            }

            // Peek: Caps Lock toggled, centred in the notch.
            Row {
                anchors.centerIn: parent
                spacing: 10
                opacity: root.mode === "peek" && NotchState.peekKind === "caps" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\ue318"
                    font.family: Colors.iconFontFamily; font.pixelSize: 18
                    color: NotchState.capsLock ? Colors.accent : root.text2
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Caps Lock " + (NotchState.capsLock ? "on" : "off")
                    font.family: Colors.fontFamily; font.pixelSize: 12; font.bold: true
                    color: root.text1
                }
            }

            // Peek: a colour was picked (already copied by hyprpicker).
            Row {
                anchors.centerIn: parent
                spacing: 10
                opacity: root.mode === "peek" && NotchState.peekKind === "color" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18; radius: 5
                    color: ColorPickerState.lastColor || "transparent"
                    border.width: 1; border.color: Qt.rgba(1, 1, 1, 0.25)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ColorPickerState.lastColor.toUpperCase()
                    font.family: Colors.fontFamily; font.pixelSize: 12; font.bold: true
                    color: root.text1
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Copied"
                    font.family: Colors.fontFamily; font.pixelSize: 11
                    color: root.text2
                }
            }

            // Peek: caffeine toggled.
            Row {
                anchors.centerIn: parent
                spacing: 10
                opacity: root.mode === "peek" && NotchState.peekKind === "caffeine" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uefef"
                    font.family: Colors.iconFontFamily; font.pixelSize: 18
                    color: CaffeineState.active ? Colors.accent : root.text2
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: CaffeineState.active ? "Caffeine on" : "Caffeine off"
                    font.family: Colors.fontFamily; font.pixelSize: 12; font.bold: true
                    color: root.text1
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: CaffeineState.active ? "Auto sleep off" : "Auto sleep after 30 min"
                    font.family: Colors.fontFamily; font.pixelSize: 11
                    color: root.text2
                }
            }

            // Peek: something started using the mic, camera or screen, centred like the other text peeks.
            Row {
                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - 32)
                spacing: 10
                opacity: root.mode === "peek" && NotchState.peekKind === "privacy" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                PrivacyDots { anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, root.width)
                    text: NotchState.privacyPeekText
                    elide: Text.ElideRight
                    font.family: Colors.fontFamily; font.pixelSize: 12; font.bold: true
                    color: root.text1
                }
            }

            // Peek: volume level or the new track.
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16; anchors.rightMargin: 16
                spacing: 10
                opacity: root.mode === "peek" && NotchState.peekKind === "volume" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                Text {
                    text: root.muted ? "" : (root.volume <= 0.5 ? "" : "")
                    font.family: Colors.iconFontFamily; font.pixelSize: 18
                    color: root.muted ? Colors.accent : root.text1
                }
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 5; radius: 3; color: "#2a2a2a"
                    Rectangle {
                        width: parent.width * Math.min(1, root.volume); height: parent.height; radius: 3
                        color: root.muted ? root.text2 : root.text1
                        Behavior on width { NumberAnimation { duration: 120 } }
                    }
                }
                Text {
                    text: Math.round(root.volume * 100)
                    Layout.preferredWidth: 30; horizontalAlignment: Text.AlignRight
                    font.family: Colors.fontFamily; font.pixelSize: 12; font.bold: true
                    color: root.text1
                }
            }
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12; anchors.rightMargin: 14
                spacing: 10
                opacity: root.mode === "peek" && NotchState.peekKind === "media" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 180 } }
                ClippingRectangle {
                    implicitWidth: 22; implicitHeight: 22; radius: 6; color: "#1a1a1a"
                    Text { visible: peekArt.status !== Image.Ready; anchors.centerIn: parent; text: "\ue405"; font.family: Colors.iconFontFamily; font.pixelSize: 15; color: root.text2 }
                    Image { id: peekArt; anchors.fill: parent; source: root.player ? root.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 64; sourceSize.height: 64 }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.player ? root.player.trackTitle + (root.player.trackArtist ? "  ·  " + root.player.trackArtist : "") : ""
                    elide: Text.ElideRight
                    font.family: Colors.fontFamily; font.pixelSize: 12; font.bold: true
                    color: root.text1
                }
                Meter { active: root.playing }
            }

            // Expanded: now playing, or a clock when nothing plays.
            ColumnLayout {
                id: expandedColumn
                anchors.fill: parent
                anchors.margins: 18
                anchors.topMargin: root.island ? 16 : 12
                spacing: 12
                opacity: root.mode === "expanded" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: 220 } }

                RowLayout {
                    id: headerRow
                    Layout.fillWidth: true; spacing: 6
                    Item {
                        implicitWidth: tabRow.implicitWidth; implicitHeight: tabRow.implicitHeight
                        Rectangle {
                            width: 30; height: 24; radius: 8; color: "#262626"
                            x: root.tabs.indexOf(root.tab) * 36
                            Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        }
                        Row {
                            id: tabRow
                            spacing: 6
                            TabButton { icon: "\uebcc"; tabId: "calendar" }
                            TabButton { icon: "\ue405"; tabId: "media" }
                            TabButton { icon: "\ue1a1"; tabId: "shelf"; count: NotchState.shelf.length }
                            TabButton { icon: "\ue322"; tabId: "system" }
                            TabButton { visible: UsageState.anyEnabled; icon: "\uf06c"; tabId: "ai" }
                        }
                    }
                    Text {
                        Layout.leftMargin: 6
                        text: root.tab === "shelf" ? "Shelf" : root.tab === "system" ? "System" : root.tab === "calendar" ? "Calendar" : root.tab === "ai" ? "AI usage" : (root.player ? (root.player.identity || "Now playing") : "Media")
                        font.family: Colors.fontFamily; font.pixelSize: 10; color: Colors.accent
                    }
                    Item { Layout.fillWidth: true }
                    PlayerDots { visible: root.tab === "media" && NotchState.players.length > 1; Layout.rightMargin: 8 }
                    PrivacyDots { Layout.rightMargin: 6 }
                    NotchButton {
                        visible: root.tab === "ai"
                        icon: "\ue5d5"; size: 17
                        enabled: !UsageState.enabledProviders.some(p => p.busy)
                        onClicked: UsageState.enabledProviders.forEach(p => p.refresh(true))
                        RotationAnimator on rotation { from: 0; to: 360; duration: 1200; loops: Animation.Infinite; running: UsageState.enabledProviders.some(p => p.busy) }
                    }
                    // Romaji toggle, only for Japanese lyrics.
                    Text {
                        visible: root.tab === "media" && root.player !== null && NotchState.lyricsHasRomaji
                        Layout.leftMargin: 4
                        text: "translate"
                        font.family: Colors.iconFontFamily; font.pixelSize: 18
                        color: NotchState.lyricsRomaji ? Colors.accent : (romajiToggleMouse.containsMouse ? root.text1 : root.text2)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        MouseArea {
                            id: romajiToggleMouse
                            anchors.fill: parent; anchors.margins: -5
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: NotchState.lyricsRomaji = !NotchState.lyricsRomaji
                        }
                    }
                    Text {
                        visible: root.tab === "media" && root.player !== null
                        Layout.leftMargin: 8
                        text: "lyrics"
                        font.family: Colors.iconFontFamily; font.pixelSize: 18
                        color: NotchState.lyricsInNotch ? Colors.accent : (lyricsToggleMouse.containsMouse ? root.text1 : root.text2)
                        Behavior on color { ColorAnimation { duration: 150 } }
                        MouseArea {
                            id: lyricsToggleMouse
                            anchors.fill: parent; anchors.margins: -5
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: NotchState.lyricsInNotch = !NotchState.lyricsInNotch
                        }
                    }
                    NotchButton { visible: root.tab === "system"; icon: "\ue89e"; size: 17; onClicked: Quickshell.execDetached(["ghostty", "-e", "btop"]) }
                    NotchButton { visible: root.tab === "shelf"; icon: "\ue14f"; size: 17; onClicked: NotchState.pasteFiles() }
                    NotchButton { visible: root.tab === "shelf" && NotchState.shelf.length > 0; Layout.leftMargin: 10; icon: "\ue16c"; size: 17; onClicked: NotchState.clearShelf() }
                }

                // Tab pages cross-fade and slide when switching.
                Item {
                    Layout.fillWidth: true; Layout.fillHeight: true

                // Lyrics under the player: the sung line centred, neighbours dimmed.
                Item {
                    id: lyricsArea
                    anchors.left: parent.left; anchors.right: parent.right
                    y: mediaRow.height + 10
                    // Five lines: two before and two after the sung one.
                    // Five lines (four with romaji): two before and two after the sung one.
                    height: root.romajiOn ? 4 * root.lyricRowHeight + 6 : 5 * root.lyricRowHeight + 6
                    opacity: root.tab === "media" && root.showLyrics ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    transform: Translate { x: root.slideOffset("media"); Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
                    HoverHandler { id: lyricsHover }
                    Rectangle { anchors.fill: parent; radius: 12; color: "#0d0d0d" }

                    ListView {
                        id: lyricsList
                        anchors.fill: parent; anchors.topMargin: 2; anchors.bottomMargin: 2
                        clip: true
                        visible: NotchState.lyricsStatus === "synced"
                        interactive: false
                        model: NotchState.lyricsStatus === "synced" ? NotchState.lyricsLines : []
                        currentIndex: Math.max(0, NotchState.lyricIndex)
                        highlightRangeMode: ListView.StrictlyEnforceRange
                        preferredHighlightBegin: height / 2 - root.lyricRowHeight / 2
                        preferredHighlightEnd: height / 2 + root.lyricRowHeight / 2
                        highlightMoveDuration: 350
                        // The sung line grows and sharpens; the others shrink, dim and blur (scale keeps layout stable).
                        // With romaji on, Japanese lines get their reading underneath.
                        delegate: Item {
                            id: lyricLine
                            required property var modelData
                            required property int index
                            readonly property bool current: index === NotchState.lyricIndex
                            readonly property bool showRomaji: root.romajiOn && (modelData.romaji || "") !== ""
                            width: ListView.view.width; height: root.lyricRowHeight
                            scale: current ? 1.4 : 0.9
                            opacity: current ? 1 : 0.5
                            Behavior on scale { NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                            property real blur: current ? 0 : 0.35
                            Behavior on blur { NumberAnimation { duration: 250 } }
                            layer.enabled: blur > 0.01
                            layer.effect: MultiEffect { blurEnabled: true; blur: lyricLine.blur; blurMax: 12 }
                            Column {
                                anchors.centerIn: parent
                                // Scaling happens after eliding, so the sung line keeps extra margin to stay inside.
                                width: parent.width - 2 * (lyricLine.current ? parent.width * 0.16 : 24)
                                spacing: 0
                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: lyricLine.modelData.text || "\u266a"
                                    elide: Text.ElideRight
                                    font.family: Colors.fontFamily; font.pixelSize: 12; font.bold: true
                                    color: lyricLine.current ? root.text1 : root.text2
                                    Behavior on color { ColorAnimation { duration: 250 } }
                                }
                                Text {
                                    visible: lyricLine.showRomaji
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: lyricLine.modelData.romaji || ""
                                    elide: Text.ElideRight
                                    font.family: Colors.fontFamily; font.pixelSize: 8
                                    color: root.text2
                                }
                            }
                        }
                    }
                    // Unsynced lyrics: scroll them with the wheel while hovering.
                    ListView {
                        id: plainLyricsList
                        anchors.fill: parent; anchors.margins: 6
                        clip: true
                        visible: NotchState.lyricsStatus === "plain"
                        model: NotchState.lyricsStatus === "plain" ? NotchState.lyricsPlain.split("\n") : []
                        boundsBehavior: Flickable.StopAtBounds
                        delegate: Text {
                            required property string modelData
                            width: ListView.view.width
                            horizontalAlignment: Text.AlignHCenter
                            text: modelData || " "
                            wrapMode: Text.WordWrap
                            font.family: Colors.fontFamily; font.pixelSize: 10
                            color: root.text1
                        }
                    }
                    Text {
                        visible: NotchState.lyricsStatus === "instrumental"
                        anchors.centerIn: parent
                        text: "\u266a  Instrumental"
                        font.family: Colors.fontFamily; font.pixelSize: 11; color: root.text2
                    }
                }

                RowLayout {
                    id: mediaRow
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    height: 110
                    opacity: root.tab === "media" && root.player !== null ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    transform: Translate { x: root.slideOffset("media"); Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
                    spacing: 14
                    ClippingRectangle {
                        implicitWidth: 84; implicitHeight: 84; radius: 14; color: "#1a1a1a"
                        Text { anchors.centerIn: parent; text: ""; font.family: Colors.iconFontFamily; font.pixelSize: 30; color: root.text2 }
                        Image { anchors.fill: parent; source: root.player ? root.player.trackArtUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 200; sourceSize.height: 200 }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 4
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 3
                                Text { Layout.fillWidth: true; text: root.player ? (root.player.trackTitle || "Unknown title") : ""; elide: Text.ElideRight; font.family: Colors.fontFamily; font.pixelSize: 14; font.bold: true; color: root.text1 }
                                Text { Layout.fillWidth: true; text: root.player ? (root.player.trackArtist || "") : ""; elide: Text.ElideRight; font.family: Colors.fontFamily; font.pixelSize: 11; color: root.text2 }
                            }
                            Meter { Layout.alignment: Qt.AlignTop; active: root.playing }
                        }
                        Item { Layout.fillHeight: true }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            visible: root.player !== null && root.player.lengthSupported && root.player.length > 0
                            Text { text: root.player ? root.formatTime(root.player.position) : ""; font.family: Colors.fontFamily; font.pixelSize: 9; color: root.text2 }
                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 4; radius: 2; color: "#2a2a2a"
                                Rectangle {
                                    width: root.player && root.player.length > 0 ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
                                    height: parent.height; radius: 2; color: root.text1
                                }
                                MouseArea {
                                    anchors.fill: parent; anchors.margins: -6
                                    enabled: root.player !== null && root.player.canSeek && root.player.positionSupported
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => { root.player.position = root.player.length * Math.max(0, Math.min(1, (mouse.x - 6) / (width - 12))) }
                                }
                            }
                            Text { text: root.player ? root.formatTime(root.player.length) : ""; font.family: Colors.fontFamily; font.pixelSize: 9; color: root.text2 }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 0
                            // Balances the volume control so playback buttons stay centred.
                            Item { implicitWidth: volumeControl.implicitWidth }
                            Item { Layout.fillWidth: true }
                            RowLayout {
                                spacing: 18
                                NotchButton { icon: "\ue045"; enabled: root.player !== null && root.player.canGoPrevious; onClicked: root.player.previous() }
                                NotchButton { icon: root.playing ? "\ue034" : "\ue037"; size: 30; enabled: root.player !== null && root.player.canTogglePlaying; onClicked: root.player.togglePlaying() }
                                NotchButton { icon: "\ue044"; enabled: root.player !== null && root.player.canGoNext; onClicked: root.player.next() }
                            }
                            Item { Layout.fillWidth: true }
                            VolumeControl { id: volumeControl }
                        }
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    opacity: root.tab === "media" && root.player === null ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    transform: Translate { x: root.slideOffset("media"); Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
                    spacing: 4
                    Item { Layout.fillHeight: true }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "\ue405"; font.family: Colors.iconFontFamily; font.pixelSize: 24; color: root.text2 }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Nothing playing"; font.family: Colors.fontFamily; font.pixelSize: 12; font.bold: true; color: root.text1 }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Play music or a video to control it here"; font.family: Colors.fontFamily; font.pixelSize: 9; color: root.text2 }
                    Item { Layout.fillHeight: true }
                }

                // Shelf: drop files here, drag them back out anywhere.
                Item {
                    anchors.fill: parent
                    opacity: root.tab === "shelf" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    transform: Translate { x: root.slideOffset("shelf"); Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                        color: dropArea.containsDrag ? Qt.alpha(Colors.accent, 0.12) : "transparent"
                        border.width: NotchState.shelf.length === 0 || dropArea.containsDrag ? 1 : 0
                        border.color: dropArea.containsDrag ? Colors.accent : "#2a2a2a"
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    Column {
                        visible: NotchState.shelf.length === 0
                        anchors.centerIn: parent; spacing: 4
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "\ue2c6"; font.family: Colors.iconFontFamily; font.pixelSize: 26; color: dropArea.containsDrag ? Colors.accent : root.text2 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: dropArea.containsDrag ? "Drop to keep it here" : "Drag files, links or text here"; font.family: Colors.fontFamily; font.pixelSize: 11; color: root.text2 }
                    }
                    ListView {
                        id: shelfList
                        anchors.fill: parent
                        anchors.margins: 4
                        orientation: ListView.Horizontal
                        spacing: 6
                        clip: true
                        interactive: !root.draggingOut
                        boundsBehavior: Flickable.StopAtBounds
                        model: NotchState.shelf
                        delegate: ShelfItem {}
                        Behavior on contentX { enabled: !shelfList.moving; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    }
                    // Thin scrollbar when the shelf overflows.
                    Rectangle {
                        visible: shelfList.contentWidth > shelfList.width
                        anchors.left: shelfList.left; anchors.right: shelfList.right; anchors.bottom: parent.bottom
                        anchors.bottomMargin: -6
                        height: 2; radius: 1; color: "#1c1c1c"
                        Rectangle {
                            x: parent.width * shelfList.visibleArea.xPosition
                            width: parent.width * shelfList.visibleArea.widthRatio
                            height: parent.height; radius: 1; color: root.text2
                        }
                    }
                }

                // Calendar: picked day on the left, month grid on the right.
                RowLayout {
                    id: calendarPage
                    anchors.fill: parent
                    opacity: root.tab === "calendar" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    transform: Translate { x: root.slideOffset("calendar"); Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
                    spacing: 16

                    ColumnLayout {
                        Layout.preferredWidth: 120; Layout.alignment: Qt.AlignTop
                        spacing: 2
                        Text { text: Qt.formatDate(root.selectedDay, "dddd"); font.family: Colors.fontFamily; font.pixelSize: 11; color: Colors.accent }
                        Text { text: root.selectedDay.getDate(); font.family: Colors.fontFamily; font.pixelSize: 44; font.bold: true; color: root.text1 }
                        Text { text: Qt.formatDate(root.selectedDay, "MMMM yyyy"); font.family: Colors.fontFamily; font.pixelSize: 11; color: root.text2 }
                        Item { implicitHeight: 6 }
                        Text {
                            id: calendarClock
                            text: Qt.formatTime(new Date(), "hh:mm:ss")
                            font.family: Colors.fontFamily; font.pixelSize: 18; font.bold: true
                            color: root.text1
                            Timer {
                                running: root.expanded && root.tab === "calendar"
                                interval: 1000; repeat: true; triggeredOnStart: true
                                onTriggered: calendarClock.text = Qt.formatTime(new Date(), "hh:mm:ss")
                            }
                        }
                        Item { implicitHeight: 2 }
                        Text {
                            readonly property int days: Math.round((new Date(root.selectedDay.getFullYear(), root.selectedDay.getMonth(), root.selectedDay.getDate())
                                - new Date(root.today.getFullYear(), root.today.getMonth(), root.today.getDate())) / 86400000)
                            text: days === 0 ? "Today" : days === 1 ? "Tomorrow" : days === -1 ? "Yesterday"
                                : days > 0 ? "In " + days + " days" : Math.abs(days) + " days ago"
                            font.family: Colors.fontFamily; font.pixelSize: 9; color: root.text2
                        }
                        Rectangle {
                            visible: !root.sameDay(root.selectedDay, root.today) || root.calendarMonth.getMonth() !== root.today.getMonth()
                                || root.calendarMonth.getFullYear() !== root.today.getFullYear()
                            Layout.topMargin: 6
                            implicitWidth: todayLabel.implicitWidth + 16; implicitHeight: 22; radius: 8
                            color: todayMouse.containsMouse ? "#262626" : "#161616"
                            Text { id: todayLabel; anchors.centerIn: parent; text: "Back to today"; font.family: Colors.fontFamily; font.pixelSize: 9; color: root.text1 }
                            MouseArea { id: todayMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.resetCalendar() }
                        }
                    }

                    Rectangle { Layout.fillHeight: true; implicitWidth: 1; color: "#1c1c1c" }

                    ColumnLayout {
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignTop
                        spacing: 4
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: Qt.formatDate(root.calendarMonth, "MMMM yyyy"); font.family: Colors.fontFamily; font.pixelSize: 11; font.bold: true; color: root.text1 }
                            Item { Layout.fillWidth: true }
                            NotchButton { icon: "\ue5cb"; size: 18; onClicked: root.shiftMonth(-1) }
                            NotchButton { Layout.leftMargin: 8; icon: "\ue5cc"; size: 18; onClicked: root.shiftMonth(1) }
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: 7; columnSpacing: 0; rowSpacing: 2
                            Repeater {
                                model: 7
                                Text {
                                    required property int index
                                    Layout.fillWidth: true; Layout.preferredWidth: 0
                                    horizontalAlignment: Text.AlignHCenter
                                    text: Qt.locale().dayName((root.firstDayOfWeek + index) % 7, Locale.ShortFormat).slice(0, 2)
                                    font.family: Colors.fontFamily; font.pixelSize: 8; color: root.text2
                                }
                            }
                            Repeater {
                                model: root.calendarDays
                                Item {
                                    id: dayCell
                                    required property var modelData
                                    readonly property bool inMonth: modelData.getMonth() === root.calendarMonth.getMonth()
                                    readonly property bool isToday: root.sameDay(modelData, root.today)
                                    readonly property bool isSelected: root.sameDay(modelData, root.selectedDay)
                                    Layout.fillWidth: true; Layout.preferredWidth: 0
                                    implicitHeight: 20
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 22; height: 20; radius: 7
                                        color: dayCell.isToday ? Colors.accent
                                            : dayCell.isSelected ? "#2a2a2a"
                                            : dayMouse.containsMouse ? "#161616" : "transparent"
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: dayCell.modelData.getDate()
                                        font.family: Colors.fontFamily; font.pixelSize: 10; font.bold: dayCell.isToday || dayCell.isSelected
                                        color: dayCell.isToday ? Colors.accentText : dayCell.inMonth ? root.text1 : "#4a4a4a"
                                    }
                                    MouseArea {
                                        id: dayMouse
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.selectedDay = dayCell.modelData
                                            if (!dayCell.inMonth) root.calendarMonth = new Date(dayCell.modelData.getFullYear(), dayCell.modelData.getMonth(), 1)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // AI usage: one provider at a time, switched with tabs.
                ColumnLayout {
                    id: aiPage
                    anchors.fill: parent
                    opacity: root.tab === "ai" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    transform: Translate { x: root.slideOffset("ai"); Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
                    spacing: 8
                    Row {
                        visible: UsageState.enabledProviders.length > 1
                        spacing: 4
                        Repeater {
                            model: UsageState.enabledProviders
                            Rectangle {
                                id: providerTab
                                required property var modelData
                                readonly property bool selected: UsageState.current === modelData
                                width: providerRow.implicitWidth + 20; height: 24; radius: 8
                                color: selected ? "#262626" : (providerMouse.containsMouse ? "#161616" : "transparent")
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Row {
                                    id: providerRow
                                    anchors.centerIn: parent; spacing: 6
                                    // Only shown when the provider failed to report usage.
                                    Rectangle { visible: providerTab.modelData.error !== ""; anchors.verticalCenter: parent.verticalCenter; width: 6; height: 6; radius: 3; color: Colors.accent }
                                    Text { text: providerTab.modelData.name; font.family: Colors.fontFamily; font.pixelSize: 10; font.bold: providerTab.selected; color: providerTab.selected ? root.text1 : root.text2 }
                                }
                                MouseArea { id: providerMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: UsageState.currentTab = providerTab.modelData.key }
                            }
                        }
                    }
                    UsageCard { provider: UsageState.current }
                }

                // System: live stats, streamed only while this tab is open.
                ColumnLayout {
                    anchors.fill: parent
                    opacity: root.tab === "system" ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    transform: Translate { x: root.slideOffset("system"); Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } } }
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        StatTile {
                            label: "CPU"
                            value: root.sys ? Math.round(root.sys.cpu) + "%" : "–"
                            detail: root.sys && root.sys.cpuTemp !== null ? Math.round(root.sys.cpuTemp) + "°C" : ""
                            hot: root.sys !== null && (root.sys.cpu > 85 || root.sys.cpuTemp > 85)
                            history: NotchState.cpuHistory
                        }
                        StatTile {
                            label: "RAM"
                            value: root.sys ? root.formatBytes(root.sys.mem.used) : "–"
                            detail: root.sys ? "of " + root.formatBytes(root.sys.mem.total) : ""
                            fraction: root.sys ? root.sys.mem.used / root.sys.mem.total : 0
                            hot: fraction > 0.9
                        }
                        StatTile {
                            visible: root.sys !== null && root.sys.gpu !== null
                            label: "GPU"
                            value: root.sys && root.sys.gpu ? Math.round(root.sys.gpu.util) + "%" : "–"
                            detail: root.sys && root.sys.gpu ? Math.round(root.sys.gpu.temp) + "°C · " + root.formatBytes(root.sys.gpu.memUsed) : ""
                            fraction: root.sys && root.sys.gpu ? root.sys.gpu.util / 100 : 0
                            hot: root.sys !== null && root.sys.gpu !== null && root.sys.gpu.temp > 85
                        }
                        StatTile {
                            visible: root.sys === null || root.sys.gpu === null
                            label: "SWAP"
                            value: root.sys ? root.formatBytes(root.sys.mem.swapUsed) : "–"
                            detail: root.sys ? "of " + root.formatBytes(root.sys.mem.swapTotal) : ""
                            fraction: root.sys && root.sys.mem.swapTotal > 0 ? root.sys.mem.swapUsed / root.sys.mem.swapTotal : 0
                        }
                        StatTile {
                            label: "DISK" + (root.sys && root.sys.disk.temp !== null ? "  ·  " + Math.round(root.sys.disk.temp) + "°C" : "")
                            value: root.sys ? Math.round(100 * root.sys.disk.used / root.sys.disk.total) + "%" : "–"
                            detail: root.sys ? root.formatBytes(root.sys.disk.total - root.sys.disk.used) + " free" : ""
                            fraction: root.sys ? root.sys.disk.used / root.sys.disk.total : 0
                            hot: fraction > 0.9
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 8
                        Rectangle {
                            Layout.preferredWidth: 124; Layout.fillHeight: true; radius: 12; color: "#111111"
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 10; spacing: 3
                                Text { text: "NET" + (root.sys && root.sys.net.iface ? "  ·  " + root.sys.net.iface : ""); font.family: Colors.fontFamily; font.pixelSize: 8; color: root.text2 }
                                Item { Layout.fillHeight: true }
                                Text { text: "\u2193 " + (root.sys ? root.formatBytes(root.sys.net.rx) + "/s" : "–"); font.family: Colors.fontFamily; font.pixelSize: 11; font.bold: true; color: root.text1 }
                                Text { text: "\u2191 " + (root.sys ? root.formatBytes(root.sys.net.tx) + "/s" : "–"); font.family: Colors.fontFamily; font.pixelSize: 11; font.bold: true; color: root.text2 }
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true; radius: 12; color: "#111111"
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 10; spacing: 2
                                Text { text: "TOP PROCESSES"; font.family: Colors.fontFamily; font.pixelSize: 8; color: root.text2 }
                                Item { Layout.fillHeight: true }
                                Repeater {
                                    model: root.sys ? root.sys.top : []
                                    RowLayout {
                                        required property var modelData
                                        Layout.fillWidth: true; spacing: 8
                                        Text { Layout.fillWidth: true; text: modelData.name; elide: Text.ElideRight; font.family: Colors.fontFamily; font.pixelSize: 10; color: root.text1 }
                                        Text { text: root.formatBytes(modelData.mem); font.family: Colors.fontFamily; font.pixelSize: 9; color: root.text2 }
                                        Text { Layout.preferredWidth: 38; horizontalAlignment: Text.AlignRight; text: modelData.cpu.toFixed(1) + "%"; font.family: Colors.fontFamily; font.pixelSize: 10; font.bold: true; color: modelData.cpu > 50 ? Colors.accent : root.text1 }
                                    }
                                }
                            }
                        }
                    }
                }
                }
            }
        }
    }

    component VolumeControl: RowLayout {
        spacing: 6
        Text {
            text: root.muted ? "\ue04f" : (root.volume <= 0.5 ? "\ue04d" : "\ue050")
            font.family: Colors.iconFontFamily; font.pixelSize: 16
            color: muteMouse.containsMouse ? Colors.accent : (root.muted ? root.text2 : root.text1)
            MouseArea {
                id: muteMouse
                anchors.fill: parent; anchors.margins: -4
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: if (root.sink && root.sink.audio) root.sink.audio.muted = !root.sink.audio.muted
            }
        }
        Item {
            implicitWidth: 64; implicitHeight: 14
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 4; radius: 2; color: "#2a2a2a"
                Rectangle {
                    width: parent.width * Math.min(1, root.volume); height: parent.height; radius: 2
                    color: root.muted ? root.text2 : root.text1
                }
            }
            Rectangle {
                visible: volumeMouse.containsMouse || volumeMouse.pressed
                x: parent.width * Math.min(1, root.volume) - width / 2
                anchors.verticalCenter: parent.verticalCenter
                width: 10; height: 10; radius: 5; color: root.text1
            }
            MouseArea {
                id: volumeMouse
                anchors.fill: parent; anchors.margins: -4
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                function apply(mouse) { root.setVolume((mouse.x - 4) / (width - 8)) }
                onPressed: mouse => apply(mouse)
                onPositionChanged: mouse => { if (pressed) apply(mouse) }
            }
        }
    }

    // One dot per media player; the wide one is shown. Click to switch.
    // Centred text that scrolls back and forth when it does not fit, with faded edges while scrolling.
    component Marquee: Item {
        id: marquee
        property alias text: label.text
        property alias font: label.font
        property alias color: label.color
        property bool scrolling: true
        readonly property bool overflowing: scrolling && label.implicitWidth > width
        property real offset: 0
        implicitHeight: label.implicitHeight
        height: label.implicitHeight
        clip: true

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            x: marquee.overflowing ? marquee.offset : (marquee.width - implicitWidth) / 2
            onTextChanged: marquee.restart()
        }
        function restart() {
            offset = 0
            scroll.stop()
            if (overflowing && visible) scroll.start()
        }
        onOverflowingChanged: restart()
        onVisibleChanged: restart()

        SequentialAnimation {
            id: scroll
            loops: Animation.Infinite
            PauseAnimation { duration: 800 }
            NumberAnimation {
                target: marquee; property: "offset"
                to: marquee.width - label.implicitWidth
                duration: Math.max(800, (label.implicitWidth - marquee.width) * 22)
                easing.type: Easing.InOutSine
            }
            PauseAnimation { duration: 1000 }
            NumberAnimation { target: marquee; property: "offset"; to: 0; duration: 450; easing.type: Easing.InOutCubic }
        }

        Rectangle {
            visible: marquee.overflowing && marquee.offset < 0
            anchors.left: parent.left; width: 14; height: parent.height
            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: root.ink } GradientStop { position: 1; color: "transparent" } }
        }
        Rectangle {
            visible: marquee.overflowing && marquee.offset > marquee.width - label.implicitWidth
            anchors.right: parent.right; width: 14; height: parent.height
            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: root.ink } }
        }
    }

    component PlayerDots: Row {
        spacing: 4
        Repeater {
            model: NotchState.players
            Item {
                id: playerDot
                required property var modelData
                readonly property bool selected: NotchState.player === modelData
                width: dot.width + 4; height: 14
                Rectangle {
                    id: dot
                    anchors.centerIn: parent
                    width: playerDot.selected ? 18 : 7; height: 7; radius: 3.5
                    color: playerDot.selected ? Colors.accent : (dotMouse.containsMouse ? root.text1 : root.text2)
                    opacity: playerDot.selected || dotMouse.containsMouse ? 1 : 0.6
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                MouseArea {
                    id: dotMouse
                    anchors.fill: parent; anchors.margins: -3
                    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: NotchState.selectPlayer(playerDot.modelData)
                }
            }
        }
    }

    component PrivacyDots: Row {
        id: dots
        readonly property var p: NotchState.privacy
        visible: NotchState.privacyActive
        spacing: 4
        Repeater {
            model: [
                { on: dots.p.camera.length > 0, color: "#30D158" },
                { on: dots.p.screen.length > 0, color: "#5E9EFF" },
                { on: dots.p.mic.length > 0, color: "#FF9F0A" }
            ]
            Rectangle {
                required property var modelData
                visible: modelData.on
                anchors.verticalCenter: parent.verticalCenter
                width: 7; height: 7; radius: 3.5
                color: modelData.color
                SequentialAnimation on opacity {
                    running: visible; loops: Animation.Infinite
                    NumberAnimation { to: 0.45; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
        }
    }

    component UsageCard: Rectangle {
        id: card
        property var provider: null
        Layout.fillWidth: true; Layout.fillHeight: true
        implicitHeight: usageColumn.implicitHeight + 24
        radius: 12; color: "#111111"
        ColumnLayout {
            id: usageColumn
            anchors.fill: parent; anchors.margins: 12; spacing: 10
            Text {
                text: card.provider ? card.provider.name : ""
                font.family: Colors.fontFamily; font.pixelSize: 12; font.bold: true
                color: root.text1
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 16
                Repeater {
                    model: ["session", "weekly"]
                    ColumnLayout {
                        id: quota
                        required property string modelData
                        readonly property var window: card.provider ? (modelData === "session" ? card.provider.session : card.provider.weekly) : null
                        readonly property bool low: window !== null && window.usedPercent >= 90
                        Layout.fillWidth: true; Layout.preferredWidth: 0; spacing: 3
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: quota.modelData === "session" ? "Session · 5h" : "Weekly"; font.family: Colors.fontFamily; font.pixelSize: 9; color: root.text2 }
                            Item { Layout.fillWidth: true }
                            Text { text: UsageState.remaining(quota.window); font.family: Colors.fontFamily; font.pixelSize: 15; font.bold: true; color: quota.low ? Colors.accent : root.text1 }
                        }
                        Rectangle {
                            Layout.fillWidth: true; implicitHeight: 4; radius: 2; color: "#2a2a2a"
                            Rectangle {
                                width: parent.width * (quota.window ? Math.max(0, 100 - quota.window.usedPercent) / 100 : 0)
                                height: parent.height; radius: 2
                                color: quota.low ? Colors.accent : root.text1
                                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                            }
                        }
                        Text { Layout.fillWidth: true; text: UsageState.countdown(quota.window); elide: Text.ElideRight; font.family: Colors.fontFamily; font.pixelSize: 8; color: root.text2 }
                    }
                }
            }
            // Status gets its own line so long errors wrap instead of being cut.
            Text {
                Layout.fillWidth: true
                text: !card.provider ? ""
                    : card.provider.error ? (card.provider.updatedAt ? "Last known data · " : "") + card.provider.error
                    : card.provider.busy ? "Refreshing usage…"
                    : card.provider.updatedAt ? "Updated " + Qt.formatDateTime(new Date(card.provider.updatedAt * 1000), "HH:mm") + " · Refreshes every 5 min"
                    : "Fetching " + card.provider.name + " usage…"
                wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                font.family: Colors.fontFamily; font.pixelSize: 9
                color: card.provider && card.provider.error ? Colors.accentLight : root.text2
            }
        }
    }

    component StatTile: Rectangle {
        id: tile
        property string label: ""
        property string value: ""
        property string detail: ""
        property real fraction: history.length > 0 ? history[history.length - 1] / 100 : 0
        property var history: []
        property bool hot: false
        // Low loads stay readable: scale to the recent peak, at least 25%.
        readonly property real peak: Math.max(25, ...history)
        Layout.fillWidth: true; Layout.preferredWidth: 0
        implicitHeight: 80; radius: 12; color: "#111111"
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 10; spacing: 2
            Text { text: tile.label; font.family: Colors.fontFamily; font.pixelSize: 8; color: root.text2 }
            Text { text: tile.value; font.family: Colors.fontFamily; font.pixelSize: 16; font.bold: true; color: tile.hot ? Colors.accent : root.text1 }
            Text { Layout.fillWidth: true; text: tile.detail; elide: Text.ElideRight; font.family: Colors.fontFamily; font.pixelSize: 8; color: root.text2 }
            Item { Layout.fillHeight: true }
            // Sparkline when there is history, otherwise a usage bar.
            Item {
                Layout.fillWidth: true; implicitHeight: tile.history.length > 0 ? 14 : 3
                Row {
                    visible: tile.history.length > 0
                    anchors.fill: parent; spacing: 1
                    layoutDirection: Qt.RightToLeft
                    Repeater {
                        model: tile.history.slice().reverse().slice(0, Math.floor((parent.width + 1) / 3))
                        Rectangle {
                            required property real modelData
                            y: parent.height - height
                            width: 2; height: Math.max(2, parent.height * modelData / tile.peak); radius: 1
                            color: modelData > 85 ? Colors.accent : "#8a8a8a"
                        }
                    }
                }
                Rectangle {
                    visible: tile.history.length === 0
                    anchors.fill: parent; radius: 1.5; color: "#2a2a2a"
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(1, tile.fraction)); height: parent.height; radius: 1.5
                        color: tile.hot ? Colors.accent : root.text1
                        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }

    component TabButton: Rectangle {
        id: tabBtn
        property string icon: ""
        property string tabId: ""
        property int count: 0
        readonly property bool current: root.tab === tabId
        implicitWidth: 30; implicitHeight: 24; radius: 8
        color: !current && tabMouse.containsMouse ? "#161616" : "transparent"
        Text { anchors.centerIn: parent; text: tabBtn.icon; font.family: Colors.iconFontFamily; font.pixelSize: 16; color: tabBtn.current ? root.text1 : root.text2; Behavior on color { ColorAnimation { duration: 200 } } }
        Rectangle {
            visible: tabBtn.count > 0
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: -2
            width: Math.max(14, countText.implicitWidth + 6); height: 14; radius: 7; color: Colors.accent
            Text { id: countText; anchors.centerIn: parent; text: tabBtn.count; font.family: Colors.fontFamily; font.pixelSize: 8; font.bold: true; color: Colors.accentText }
        }
        MouseArea { id: tabMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.tab = tabBtn.tabId }
    }

    component ShelfItem: Item {
        id: item
        required property var modelData
        required property int index
        readonly property string kind: typeof modelData === "string" ? "file" : (modelData.url !== undefined ? "link" : "text")
        readonly property string path: kind === "file" ? modelData : ""
        readonly property string linkHost: kind === "link" ? modelData.url.replace(/^https?:\/\//, "").split(/[\/?#]/)[0] : ""
        readonly property string name: kind === "file" ? path.split("/").pop()
            : kind === "link" ? linkHost
            : modelData.text.trim().split("\n")[0]
        readonly property string ext: kind === "file" && name.includes(".") ? name.split(".").pop().toLowerCase() : ""
        readonly property bool isImage: ["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg", "avif"].includes(ext)
        readonly property string fileUrl: kind === "file" ? "file://" + path.split("/").map(encodeURIComponent).join("/") : ""
        // Sized to its content so the hover background hugs the thumbnail and name.
        width: 76; height: 84

        function iconFor(e) {
            if (item.kind === "link") return "\ue157"
            if (item.kind === "text") return "\ue262"
            if (e === "") return "\ue2c7"
            if (e === "pdf") return "\ue415"
            if (["mp4", "mkv", "webm", "mov", "avi"].includes(e)) return "\ue02c"
            if (["mp3", "flac", "wav", "ogg", "m4a", "opus"].includes(e)) return "\ue405"
            if (["zip", "tar", "gz", "xz", "7z", "rar", "zst"].includes(e)) return "\ueb2c"
            if (["txt", "md", "doc", "docx", "odt", "rtf"].includes(e)) return "\ue873"
            if (["js", "ts", "py", "qml", "rs", "go", "c", "cpp", "h", "sh", "json", "lua", "html", "css"].includes(e)) return "\ue86f"
            return "\ue66d"
        }

        Rectangle {
            id: card
            anchors.fill: parent
            radius: 12
            color: dragArea.containsMouse || dragArea.drag.active ? "#1c1c1c" : "transparent"
            Drag.active: dragArea.drag.active
            Drag.dragType: Drag.Automatic
            Drag.supportedActions: Qt.CopyAction
            // The portal key lets sandboxed apps (Flatpak) read the file; GTK sends it NUL-terminated.
            // GTK3 apps (e.g. Flutter) look for the older "vnd.portal.files" name, GTK4 and Qt for "filetransfer".
            Drag.mimeData: {
                if (item.kind === "text") return { "text/plain": item.modelData.text }
                if (item.kind === "link") return { "text/uri-list": item.modelData.url + "\r\n", "text/plain": item.modelData.url }
                const data = { "text/uri-list": item.fileUrl + "\r\n", "text/plain": item.path }
                const key = NotchState.transferKeys[item.path]
                if (key) {
                    data["application/vnd.portal.filetransfer"] = key + "\u0000"
                    data["application/vnd.portal.files"] = key + "\u0000"
                }
                return data
            }
            Drag.onDragFinished: {
                root.draggingOut = false
                collapseTimer.restart()
            }

            ClippingRectangle {
                id: thumb
                anchors.horizontalCenter: parent.horizontalCenter
                y: 6; width: 52; height: 52; radius: 10; color: "#1a1a1a"
                Text { visible: item.kind !== "text" && (!item.isImage || thumbImage.status !== Image.Ready); anchors.centerIn: parent; text: item.iconFor(item.ext); font.family: Colors.iconFontFamily; font.pixelSize: 26; color: root.text1 }
                // Text snippets preview their first lines.
                Text {
                    visible: item.kind === "text"
                    anchors.fill: parent; anchors.margins: 6
                    text: item.kind === "text" ? item.modelData.text : ""
                    wrapMode: Text.WrapAnywhere; elide: Text.ElideRight; maximumLineCount: 5
                    font.family: Colors.fontFamily; font.pixelSize: 7; lineHeight: 0.95
                    color: root.text1
                }
                Image { id: thumbImage; visible: item.isImage; anchors.fill: parent; source: item.isImage ? item.fileUrl : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; sourceSize.width: 128; sourceSize.height: 128 }
            }
            Timer { id: copiedTimer; interval: 1200 }
            Text {
                anchors.top: thumb.bottom; anchors.topMargin: 6
                anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 4; anchors.rightMargin: 4
                text: copiedTimer.running ? "Copied" : item.name
                elide: item.kind === "file" ? Text.ElideMiddle : Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                font.family: Colors.fontFamily; font.pixelSize: 9; color: root.text2
            }
            MouseArea {
                id: dragArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                drag.target: dragProxy
                drag.threshold: 6
                onPressed: thumb.grabToImage(r => { card.Drag.imageSource = r.url }, Qt.size(52, 52))
                drag.onActiveChanged: if (drag.active) root.draggingOut = true
                // Files and links open; text is copied to the clipboard.
                onClicked: {
                    if (item.kind === "text") {
                        Quickshell.execDetached(["wl-copy", "--", item.modelData.text])
                        copiedTimer.restart()
                    } else {
                        Quickshell.execDetached(["xdg-open", item.kind === "link" ? item.modelData.url : item.path])
                    }
                }
            }
            // Dragged instead of the card so the list layout does not move.
            Item { id: dragProxy; width: 52; height: 52 }

            Rectangle {
                visible: dragArea.containsMouse || removeMouse.containsMouse
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 2
                width: 18; height: 18; radius: 9; color: removeMouse.containsMouse ? Colors.accent : "#333333"
                Text { anchors.centerIn: parent; text: "\ue5cd"; font.family: Colors.iconFontFamily; font.pixelSize: 12; color: root.text1 }
                MouseArea { id: removeMouse; anchors.fill: parent; anchors.margins: -3; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: NotchState.removeEntry(item.modelData) }
            }
        }
    }

    component NotchButton: Text {
        id: btn
        property string icon: ""
        property int size: 24
        signal clicked()
        text: icon
        font.family: Colors.iconFontFamily
        font.pixelSize: size
        color: btnMouse.containsMouse ? Colors.accent : root.text1
        opacity: enabled ? 1 : 0.35
        MouseArea { id: btnMouse; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
    }

    // Decorative level meter; animates while something plays.
    // Fixed size, so layouts cannot collapse it.
    component Meter: Item {
        id: meter
        property bool active: false
        implicitWidth: 18
        implicitHeight: 14
        Row {
            anchors.fill: parent
            spacing: 2
            Repeater {
                model: 4
                Rectangle {
                    id: barRect
                    required property int index
                    property real level: 0.3
                    y: meter.implicitHeight - height
                    width: 3; radius: 1.5
                    height: meter.implicitHeight * (meter.active ? level : 0.2)
                    color: Colors.accent
                    Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }
                    Timer {
                        running: meter.active && meter.visible
                        interval: 140 + barRect.index * 35
                        repeat: true
                        onTriggered: barRect.level = 0.25 + Math.random() * 0.75
                    }
                }
            }
        }
    }
}
