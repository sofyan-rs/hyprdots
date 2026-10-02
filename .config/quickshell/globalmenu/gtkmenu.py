"""Read exported GTK GMenu models and dispatch their original GActions."""
import re
import zlib

import dbus

MENUS = "org.gtk.Menus"
ACTIONS = "org.gtk.Actions"


class GtkMenu:
    def __init__(self, bus, service, path, action_paths):
        self.bus, self.service, self.path = bus, service, path
        self.action_paths = action_paths
        self.commands = {}

    def interface(self, path, interface):
        return dbus.Interface(self.bus.get_object(self.service, path, introspect=False), interface)

    def read(self):
        remote = self.interface(self.path, MENUS)
        groups, models, descriptions = set(), {}, {}
        self.commands = {}
        for path in self.action_paths:
            try:
                descriptions[path] = self.interface(path, ACTIONS).DescribeAll(timeout=0.5)
            except dbus.DBusException:
                continue

        def action_info(action):
            prefix, _, name = action.partition(".")
            if not name:
                name, prefix = prefix, ""
            if prefix == "app":
                candidates = [p for p in descriptions if "/window/" not in p]
            elif prefix == "win":
                candidates = [p for p in descriptions if "/window/" in p]
                # Wayland PID alone cannot identify one of several GTK windows.
                if len(candidates) != 1:
                    return None
            else:
                candidates = [self.path] if self.path in descriptions else list(descriptions)
            matches = [(p, name, descriptions[p][name]) for p in candidates if name in descriptions[p]]
            return matches[0] if len(matches) == 1 else None

        def items(group, menu_id, ancestors=()):
            key = (int(group), int(menu_id))
            if key in ancestors or len(ancestors) > 16:
                return []
            if int(group) not in groups:
                rows = remote.Start(dbus.Array([int(group)], signature="u"), timeout=0.5)
                groups.add(int(group))
                for g, m, content in rows:
                    models[int(g), int(m)] = content
            result = []
            for index, props in enumerate(models.get(key, [])):
                section = props.get(":section", props.get("section"))
                submenu = props.get(":submenu", props.get("submenu"))
                identifier = zlib.crc32(f"{key}:{index}".encode()) & 0x7fffffff
                if section is not None:
                    content = items(*section, ancestors + (key,))
                    if content:
                        if result:
                            result.append(dict(id=identifier, label="", enabled=False, visible=True, separator=True, icon="", shortcut="", checked=False, submenu=False, children=[]))
                        result.extend(content)
                    continue
                label = re.sub(r"(?<!_)_(?!_)", "", str(props.get("label", ""))).replace("__", "_")
                action = action_info(str(props.get("action", ""))) if "action" in props else None
                target = props.get("target")
                checked = False
                toggle_type = ""
                if action:
                    path, name, (enabled, parameter_type, state) = action
                    checked = bool(state and (state[0] == target if target is not None else isinstance(state[0], dbus.Boolean) and bool(state[0])))
                    if state:
                        toggle_type = "radio" if target is not None else "checkmark" if isinstance(state[0], dbus.Boolean) else ""
                    if enabled and (not parameter_type or target is not None):
                        self.commands[identifier] = (path, name, target)
                children = items(*submenu, ancestors + (key,)) if submenu is not None else []
                accel = str(props.get("accel", ""))
                for source, dest in [("<Primary>", "Ctrl+"), ("<Control>", "Ctrl+"), ("<Shift>", "Shift+"), ("<Alt>", "Alt+")]:
                    accel = accel.replace(source, dest)
                result.append(dict(id=identifier, label=label, enabled=submenu is not None or identifier in self.commands, visible=True, separator=False, icon="", shortcut=accel, checked=checked, toggle_type=toggle_type, submenu=submenu is not None, children=children))
            return result

        try:
            nodes = items(0, 0)
            if nodes and not all(node["submenu"] or node["separator"] for node in nodes):
                # GTK app-menu exports have one flat application menu.
                nodes = [dict(id=-1, label="Application", enabled=True, visible=True, separator=False, icon="", shortcut="", checked=False, submenu=True, children=nodes)]
            return nodes
        finally:
            if groups:
                remote.End(dbus.Array(sorted(groups), signature="u"), timeout=0.5)

    def activate(self, identifier):
        # Refresh enablement before dispatching a command.
        expected = self.commands.get(identifier)
        self.read()
        command = self.commands.get(identifier)
        if not command or command != expected:
            return
        path, name, target = command
        args = dbus.Array([] if target is None else [target], signature="v")
        self.interface(path, ACTIONS).Activate(name, args, dbus.Dictionary({}, signature="sv"), timeout=1)
