"""AppMenu registrar and DBusMenu bridge for the focused Hyprland application."""
import json
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

import dbus
import dbus.service
from dbus.mainloop.glib import DBusGMainLoop
from gi.repository import GLib
from gtkmenu import GtkMenu, MENUS as GTK_MENUS, ACTIONS as GTK_ACTIONS
from nautilusmenu import NautilusMenu

REGISTRAR = "com.canonical.AppMenu.Registrar"
MENU = "com.canonical.dbusmenu"


def focused_window():
    result = subprocess.run(["hyprctl", "activewindow", "-j"], capture_output=True, text=True, timeout=1)
    return json.loads(result.stdout or "{}")


def normalize(node):
    item_id, props, children = node
    label = str(props.get("label", ""))
    label = re.sub(r"(?<!_)_(?!_)", "", label).replace("__", "_")
    shortcuts = props.get("shortcut", [])
    shortcut = "+".join(str(key).replace("Control", "Ctrl") for key in shortcuts[0]) if shortcuts else ""
    return {
        "id": int(item_id), "label": label,
        "enabled": bool(props.get("enabled", True)),
        "visible": bool(props.get("visible", True)),
        "separator": props.get("type") == "separator",
        "icon": str(props.get("icon-name", "")),
        "shortcut": shortcut,
        "checked": int(props.get("toggle-state", 0)) == 1,
        "toggle_type": str(props.get("toggle-type", "")),
        "submenu": props.get("children-display") == "submenu" or bool(children),
        "children": [normalize(child) for child in children],
    }


def emit(value):
    print(json.dumps(value), flush=True)


class Registrar(dbus.service.Object):
    def __init__(self, bus, changed):
        self.entries = {}
        self.changed = changed
        self.name = dbus.service.BusName(REGISTRAR, bus, do_not_queue=True)
        super().__init__(self.name, "/com/canonical/AppMenu/Registrar")

    @dbus.service.method(REGISTRAR, in_signature="uo", sender_keyword="sender")
    def RegisterWindow(self, window_id, path, sender=None):
        self.entries[int(window_id)] = (str(sender), str(path))
        self.WindowRegistered(window_id, sender, path)
        self.changed()

    @dbus.service.method(REGISTRAR, in_signature="u")
    def UnregisterWindow(self, window_id):
        self.entries.pop(int(window_id), None)
        self.WindowUnregistered(window_id)
        self.changed()

    @dbus.service.method(REGISTRAR, in_signature="u", out_signature="so")
    def GetMenuForWindow(self, window_id):
        return self.entries.get(int(window_id), ("", "/"))

    @dbus.service.method(REGISTRAR, out_signature="a(uso)")
    def GetMenus(self):
        return [(key, *value) for key, value in self.entries.items()]

    @dbus.service.signal(REGISTRAR, signature="uso")
    def WindowRegistered(self, window_id, service, path):
        pass

    @dbus.service.signal(REGISTRAR, signature="u")
    def WindowUnregistered(self, window_id):
        pass


class Bridge:
    def __init__(self):
        self.bus = dbus.SessionBus()
        self.registrar = None
        self.state = {"address": "", "class": "", "pid": 0, "menus": [], "token": ""}
        self.endpoint = None
        self.signal_matches = []
        self.cache = {}
        self.force = True
        self.gtk_menu = None
        self.menu_revision = None
        self.pending_checks = None
        self.refresh_submenu = None
        try:
            self.registrar = Registrar(self.bus, self.invalidate)
        except dbus.DBusException:
            pass  # Respect an existing registrar.
        self.bus.add_signal_receiver(self.owner_changed, signal_name="NameOwnerChanged", dbus_interface="org.freedesktop.DBus")
        GLib.timeout_add(500, self.poll)
        GLib.io_add_watch(sys.stdin, GLib.IO_IN | GLib.IO_HUP, self.input)
        self.poll()

    def invalidate(self, *args):
        self.force = True
        self.cache.clear()

    def owner_changed(self, name, old, new):
        relevant = str(name) == REGISTRAR or (self.endpoint and str(name) == self.endpoint[0])
        if old and not new and self.registrar:
            relevant = relevant or any(value[0] == str(name) for value in self.registrar.entries.values())
            self.registrar.entries = {key: value for key, value in self.registrar.entries.items() if value[0] != str(name)}
        if relevant:
            self.invalidate()

    def discover(self, bus, window, registrations):
        pid = int(window.get("pid", 0))
        if not pid:
            return None
        if window.get("xwayland"):
            try:
                result = subprocess.run(["xprop", "-root", "_NET_ACTIVE_WINDOW"], capture_output=True, text=True, timeout=0.5)
                match = re.search(r"0x[0-9a-fA-F]+", result.stdout)
                if match:
                    xid = int(match[0], 16)
                    if xid in registrations:
                        return registrations[xid]
                    if self.registrar is None and bus.name_has_owner(REGISTRAR):
                        service, path = dbus.Interface(bus.get_object(REGISTRAR, "/com/canonical/AppMenu/Registrar", introspect=False), REGISTRAR).GetMenuForWindow(dbus.UInt32(xid), timeout=0.5)
                        if service:
                            return str(service), str(path)
            except Exception:
                pass
        services = []
        daemon = dbus.Interface(bus.get_object("org.freedesktop.DBus", "/org/freedesktop/DBus"), "org.freedesktop.DBus")
        for name in bus.list_names():
            if not str(name).startswith(":"):
                continue
            try:
                if int(daemon.GetConnectionUnixProcessID(name, timeout=0.5)) == pid:
                    services.append(str(name))
            except dbus.DBusException:
                pass
        for service, path in registrations.values():
            if service in services:
                return service, path
        # Some Wayland applications export a menu without an X11 registration.
        for service in services:
            queue = [("/", 0)]
            seen = set()
            gtk_paths, action_paths = [], []
            while queue and len(seen) < 48:
                path, depth = queue.pop(0)
                if path in seen or depth > 6 or re.search(r"tray|StatusNotifier", path, re.I):
                    continue
                seen.add(path)
                try:
                    xml = dbus.Interface(bus.get_object(service, path, introspect=False), "org.freedesktop.DBus.Introspectable").Introspect(timeout=0.35)
                    tree = ET.fromstring(str(xml))
                    interfaces = [interface.attrib.get("name") for interface in tree.findall("interface")]
                    if GTK_MENUS in interfaces:
                        gtk_paths.append(path)
                    if GTK_ACTIONS in interfaces:
                        action_paths.append(path)
                    if any(interface.attrib.get("name") == MENU for interface in tree.findall("interface")):
                        menu = dbus.Interface(bus.get_object(service, path, introspect=False), MENU)
                        _, layout = menu.GetLayout(0, 1, dbus.Array([], signature="s"), timeout=0.5)
                        nodes = normalize(layout)["children"]
                        if nodes and all(node["submenu"] or node["separator"] for node in nodes):
                            return service, path
                    for child in tree.findall("node"):
                        child_path = path.rstrip("/") + "/" + child.attrib["name"]
                        queue.append((child_path, depth + 1))
                except Exception:
                    continue
            if gtk_paths:
                gtk_paths.sort(key=lambda path: ("menubar" not in path, "appmenu" not in path, path))
                return service, gtk_paths[0], tuple(action_paths)
            if window.get("class", "").lower() in ("org.gnome.nautilus", "nautilus") and action_paths:
                return service, "resource:nautilus", tuple(action_paths)
        return None

    def read(self, force, registrations):
        window = focused_window()
        address = window.get("address", "")
        pid = int(window.get("pid", 0))
        app_class = window.get("class", "")
        key = (address, pid, app_class)
        bus = self.bus
        cached = self.cache.get(key)
        if force or cached is None or (cached[0] is None and time.monotonic() - cached[1] > 8):
            endpoint = self.discover(bus, window, registrations)
            self.cache[key] = endpoint, time.monotonic()
        else:
            endpoint = cached[0]
        menus = []
        if endpoint:
            if len(endpoint) == 3:
                if endpoint != self.endpoint or self.gtk_menu is None:
                    adapter = NautilusMenu if endpoint[1] == "resource:nautilus" else GtkMenu
                    self.gtk_menu = adapter(bus, *endpoint)
                menus = self.gtk_menu.read()
            else:
                self.gtk_menu = None
                menu = dbus.Interface(bus.get_object(*endpoint, introspect=False), MENU)
                if self.refresh_submenu is not None and endpoint == self.endpoint:
                    submenu_id = self.refresh_submenu
                    self.refresh_submenu = None
                    try:
                        menu.AboutToShow(dbus.Int32(submenu_id), timeout=1)
                    except dbus.DBusException:
                        pass  # Applications can rebuild menu IDs after a click.
                revision, layout = menu.GetLayout(0, -1, dbus.Array([], signature="s"), timeout=1)
                self.menu_revision = int(revision)
                menus = [node for node in normalize(layout)["children"] if node["visible"]]
                if self.pending_checks:
                    old_endpoint, old_revision, checks = self.pending_checks
                    if old_endpoint == endpoint and old_revision == self.menu_revision:
                        self.apply_checks(menus, checks)
                    else:
                        self.pending_checks = None
        headings = tuple(node["id"] for node in menus)
        token = f"{address}|{pid}|{endpoint}|{headings}"
        return {"address": address, "pid": pid, "class": app_class, "menus": menus, "token": token}, endpoint

    def poll(self):
        force, self.force = self.force, False
        registrations = dict(self.registrar.entries) if self.registrar else {}
        try:
            state, endpoint = self.read(force, registrations)
            if state != self.state:
                changed_endpoint = endpoint != self.endpoint
                self.state, self.endpoint = state, endpoint
                emit(state)
                if changed_endpoint:
                    for match in self.signal_matches:
                        match.remove()
                    self.signal_matches = []
                    if endpoint and len(endpoint) == 2:
                        for signal in ["LayoutUpdated", "ItemsPropertiesUpdated"]:
                            self.signal_matches.append(self.bus.add_signal_receiver(self.invalidate, signal_name=signal, dbus_interface=MENU, bus_name=endpoint[0], path=endpoint[1]))
        except Exception as error:
            self.cache.clear()
            print(f"global-menu: {error}", file=sys.stderr)
        return True

    def input(self, stream, condition):
        if condition & GLib.IO_HUP:
            GLib.MainLoop().quit()
            raise SystemExit(0)
        line = stream.readline()
        if not line:
            return False
        try:
            request = json.loads(line)
            if request.get("token") != self.state["token"] or not self.endpoint:
                return True
            # Never send an old popup's command to a newly focused application.
            if focused_window().get("address", "") != self.state["address"]:
                return True
            item_id = int(request["id"])
            if len(self.endpoint) == 3:
                if request["action"] == "activate" and self.gtk_menu:
                    self.gtk_menu.activate(item_id)
                self.force = True
                return True
            menu = dbus.Interface(self.bus.get_object(*self.endpoint, introspect=False), MENU)
            if request["action"] == "open":
                menu.AboutToShow(dbus.Int32(item_id), timeout=1)
                self.force = True
            elif request["action"] == "activate":
                checks = self.next_checks(self.state["menus"], item_id)
                menu.Event(dbus.Int32(item_id), "clicked", dbus.Int32(0, variant_level=1), dbus.UInt32(int(time.time() * 1000) & 0xffffffff), timeout=1)
                # Electron can cache the old toggle state until its next layout
                # revision. Reflect this successful click while that revision
                # is unchanged; newer exported state always wins.
                if checks:
                    self.pending_checks = (self.endpoint, self.menu_revision, checks)
                self.refresh_submenu = request.get("parentId")
                self.force = True
        except Exception as error:
            print(f"global-menu: {error}", file=sys.stderr)
        return True

    @staticmethod
    def apply_checks(nodes, checks):
        for node in nodes:
            if node["id"] in checks:
                node["checked"] = checks[node["id"]]
            Bridge.apply_checks(node["children"], checks)

    @staticmethod
    def next_checks(nodes, item_id):
        for index, node in enumerate(nodes):
            if node["id"] == item_id and node["enabled"]:
                if node.get("toggle_type") == "checkmark":
                    return {item_id: not node["checked"]}
                if node.get("toggle_type") == "radio":
                    start, end = index, index + 1
                    while start > 0 and nodes[start - 1].get("toggle_type") == "radio":
                        start -= 1
                    while end < len(nodes) and nodes[end].get("toggle_type") == "radio":
                        end += 1
                    return {other["id"]: other["id"] == item_id for other in nodes[start:end]}
                return {}
            checks = Bridge.next_checks(node["children"], item_id)
            if checks:
                return checks
        return {}


if __name__ == "__main__":
    DBusGMainLoop(set_as_default=True)
    bridge = Bridge()
    GLib.MainLoop().run()
