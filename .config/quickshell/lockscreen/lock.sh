#!/bin/sh
# Run independently of the desktop shell. Wait for all outputs to be secured
# before returning, so hypridle's before_sleep_cmd cannot suspend too early.
set -eu
lock_config="$HOME/.config/quickshell/lock.qml"
quickshell -d -n -p "$lock_config"
i=0
while [ "$i" -lt 100 ]; do
    if [ "$(quickshell ipc -p "$lock_config" call lock isSecure 2>/dev/null || true)" = "true" ]; then
        exit 0
    fi
    i=$((i + 1))
    sleep 0.1
done
printf "%s\n" "Quickshell could not confirm the session lock." >&2
exit 1
