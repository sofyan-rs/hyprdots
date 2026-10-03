import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick

QtObject {
    id: root
    property bool preview: false
    property bool closing: false
    property bool busy: pam.active || closing
    property string error: ""
    property string secret: ""
    property string wallpaper: ""
    property string displayName: Quickshell.env("USER")
    property string distro: "Linux"
    signal authenticated()
    signal clearPassword()
    function submit(password) {
        if (preview) { error = "Preview only — session is not locked"; clearPassword(); return }
        if (busy) return
        error = ""
        secret = password
        if (!pam.start()) { secret = ""; error = "Could not start authentication"; clearPassword() }
    }
    property PamContext authentication: PamContext {
        id: pam
        // Use the same system-managed login authentication policy as the old locker.
        config: "login"
        onPamMessage: {
            if (responseRequired) {
                const response = root.secret
                root.secret = ""
                root.clearPassword()
                respond(response)
            } else if (messageIsError) root.error = message
        }
        onCompleted: result => {
            root.secret = ""
            root.clearPassword()
            if (result === PamResult.Success) { root.error = ""; root.closing = true; root.authenticated() }
            else root.error = "Authentication failed. Please try again."
        }
    }
    property FileView wallpaperFile: FileView {
        path: Quickshell.env("HOME") + "/.config/waypaper/config.ini"
        onLoaded: {
            const match = text().match(/^wallpaper\s*=\s*(.+)$/m)
            if (match) {
                let path = match[1].trim()
                if (path.startsWith("~")) path = Quickshell.env("HOME") + path.slice(1)
                root.wallpaper = "file://" + path
            }
        }
    }
    property FileView osFile: FileView {
        path: "/etc/os-release"
        onLoaded: {
            const match = text().match(/^ID=(.+)$/m)
            if (match) root.distro = match[1].replace(/"/g, "")
        }
    }
    property Process userInfo: Process {
        running: true
        command: ["getent", "passwd", Quickshell.env("USER")]
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(":")
                if (fields.length > 4 && fields[4].split(",")[0]) root.displayName = fields[4].split(",")[0]
                else if (root.displayName) root.displayName = root.displayName[0].toUpperCase() + root.displayName.slice(1)
            }
        }
    }
}
