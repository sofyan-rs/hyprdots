#!/usr/bin/env python3
import json
from pydbus import SessionBus
from gi.repository import GLib

bus = SessionBus()
mako = bus.get("org.freedesktop.Notifications", "/fr/emersion/Mako")
loop = GLib.MainLoop()

last_count = -1

def update():
    global last_count
    notifs = mako.ListNotifications()
    count = len(notifs)
    if count != last_count:
        last_count = count
        print(json.dumps({
            "text": str(count),
            "alt": f"{count} notifications",
            "class": "active" if count else "idle"
        }), flush=True)
    return True  # continue the timer

# Initial print
update()

# Poll every 2 seconds (2000 milliseconds)
GLib.timeout_add(2000, update)

loop.run()
