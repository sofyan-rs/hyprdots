#!/usr/bin/env python3
"""Register shelf files with the FileTransfer portal so sandboxed (Flatpak)
apps can receive them by drag and drop.

Reads one path per line on stdin and prints {"path": ..., "key": ...} per line.
Keys stay valid while this process (and its bus connection) is alive.
"""
import json
import os
import sys

import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

BUS_NAME = "org.freedesktop.portal.Documents"
OBJECT_PATH = "/org/freedesktop/portal/documents"
IFACE = "org.freedesktop.portal.FileTransfer"

bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)


def register(path):
    key = bus.call_sync(
        BUS_NAME, OBJECT_PATH, IFACE, "StartTransfer",
        GLib.Variant("(a{sv})", ({"writable": GLib.Variant("b", False),
                                  "autostop": GLib.Variant("b", False)},)),
        GLib.VariantType("(s)"), Gio.DBusCallFlags.NONE, -1, None).unpack()[0]
    fd = os.open(path, os.O_PATH | os.O_CLOEXEC)
    try:
        fds = Gio.UnixFDList.new()
        index = fds.append(fd)
        bus.call_with_unix_fd_list_sync(
            BUS_NAME, OBJECT_PATH, IFACE, "AddFiles",
            GLib.Variant("(saha{sv})", (key, [index], {})),
            None, Gio.DBusCallFlags.NONE, -1, fds, None)
    finally:
        os.close(fd)
    return key


for line in sys.stdin:
    path = line.rstrip("\n")
    if not path:
        continue
    try:
        result = {"path": path, "key": register(path)}
    except Exception as e:  # missing file, portal error, ...
        result = {"path": path, "error": str(e)}
    print(json.dumps(result), flush=True)
