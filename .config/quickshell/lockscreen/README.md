# Quickshell lock screen

Lock using the control center's Lock button, Super + L, or:

```sh
~/.config/quickshell/lockscreen/lock.sh
```

The locker uses a separate Quickshell process and Wayland session-lock surfaces
on every monitor. Authentication uses `/etc/pam.d/login`, the system-managed
login authentication policy. The locker runs entirely through Quickshell.
The desktop shell restart shortcut targets only
`quickshell/shell.qml`.

Hypridle invokes the launcher for loginctl lock requests and before suspend.
The launcher waits for the compositor to confirm all outputs are secured.

Preview without locking (password and power actions are disabled):

```sh
quickshell -p ~/.config/quickshell/lock-preview.qml
```

Wallpaper follows Waypaper's selected wallpaper. Display name comes from the
account record. The password field uses explicit padding and centered content. Entrance and exit
animations fade and slide the lock UI; the compositor lock is released only after
successful authentication and the exit animation. The shared control-center
PowerModal/PowerCard provides the power popup, including open/close animations.
Restart and shutdown ask for confirmation. Unlock requires a
successful PAM result; there is no IPC unlock command.

Verification: rendered in offscreen and live Wayland previews, loaded the
locker with locking disabled, tested PAM success/failure with temporary policies,
and tested launcher success and failure handling using mocked commands. Real account
password entry, session-lock acquisition, and suspend/resume require an interactive
check by the user.
