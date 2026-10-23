pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "../core"

Singleton {
    id: root
    readonly property UsageProvider codex: UsageProvider { key: "codex"; name: "Codex" }
    readonly property UsageProvider claude: UsageProvider { key: "claude"; name: "Claude" }
    readonly property var providers: [claude, codex]
    property string currentTab: "claude"
    readonly property var enabledProviders: providers.filter(p => p.enabled)
    readonly property bool anyEnabled: enabledProviders.length > 0
    readonly property UsageProvider current: enabledProviders.find(p => p.key === currentTab) || enabledProviders[0] || claude
    property bool settingsLoaded: false
    property double now: Date.now() / 1000

    function refresh() {
        providers.forEach(p => p.refresh())
    }
    function refreshStale() {
        providers.forEach(p => { if (now - p.updatedAt > 60) p.refresh() })
    }
    function remaining(window) {
        return window ? Math.round(100 - window.usedPercent) + "%" : "—"
    }
    function countdown(window) {
        if (!window || !window.resetsAt) return "Reset time unavailable"
        const minutes = Math.ceil((window.resetsAt - now) / 60)
        if (minutes <= 0) return "Waiting for quota update"
        const days = Math.floor(minutes / 1440)
        const hours = Math.floor((minutes % 1440) / 60)
        const mins = minutes % 60
        return "Resets in " + (days ? days + "d " : "") + (hours ? hours + "h " : "") + mins + "m"
    }

    FileView {
        id: settings
        path: Quickshell.env("HOME") + "/.config/quickshell/aiusage/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.settingsLoaded = false
            try {
                const data = JSON.parse(text())
                root.codex.enabled = data.codex !== false
                root.claude.enabled = data.claude !== false
                if (["codex", "claude"].includes(data.tab)) root.currentTab = data.tab
            } catch (e) { }
            root.settingsLoaded = true
            root.refresh()
        }
        onLoadFailed: {
            root.settingsLoaded = true
            root.refresh()
        }
    }
    function save() {
        if (settingsLoaded) settings.setText(JSON.stringify({ codex: codex.enabled, claude: claude.enabled, tab: currentTab }))
    }
    Connections { target: root.codex; function onEnabledChanged() { root.save() } }
    Connections { target: root.claude; function onEnabledChanged() { root.save() } }
    onCurrentTabChanged: save()

    Timer { interval: 300000; running: true; repeat: true; onTriggered: root.refresh() }
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.now = Date.now() / 1000 }
    IpcHandler {
        target: "aiusage"
        function refresh(): void { root.refresh() }
        function status(): string {
            const dump = p => ({ enabled: p.enabled, session: p.session, weekly: p.weekly,
                                 updatedAt: p.updatedAt, error: p.error, busy: p.busy })
            return JSON.stringify({ codex: dump(root.codex), claude: dump(root.claude) })
        }
        function enable(provider: string, on: bool): void {
            if (provider === "codex" || provider === "claude") root[provider].enabled = on
        }
        function toggle(): void { NotchState.tabRequested("ai") }
    }
}
