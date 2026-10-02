"""Use Nautilus's installed primary-menu resource with its live GTK actions."""
from functools import lru_cache
from pathlib import Path
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zlib

from gi.repository import Gio
from gtkmenu import GtkMenu, ACTIONS


@lru_cache(maxsize=2)
def primary_menu(executable, modification_time):
    # Read the menu shipped by this exact installed version, not a copied list.
    with tempfile.TemporaryDirectory(prefix="quickshell-nautilus-menu-") as directory:
        resource_path = str(Path(directory) / "menu.gresource")
        subprocess.run(["objcopy", "--dump-section", ".gresource.nautilus=" + resource_path,
                        executable, str(Path(directory) / "binary")], check=True, capture_output=True, timeout=2)
        resource = Gio.Resource.load(resource_path)
        xml = resource.lookup_data("/org/gnome/nautilus/ui/nautilus-window.ui", Gio.ResourceLookupFlags.NONE).get_data()
        menu = ET.fromstring(xml).find("menu[@id='app_menu']")
        if menu is None:
            raise ValueError("Installed Nautilus has no primary menu resource")
        return menu


class NautilusMenu(GtkMenu):
    def read(self):
        executable = "/usr/bin/nautilus"
        tree = primary_menu(executable, Path(executable).stat().st_mtime_ns)
        self.commands = {}
        descriptions = {}
        for path in self.action_paths:
            descriptions[path] = self.interface(path, ACTIONS).DescribeAll(timeout=0.5)

        def item(element, position):
            attrs = {attribute.get("name"): attribute.text or "" for attribute in element.findall("attribute")}
            identifier = zlib.crc32(position.encode()) & 0x7fffffff
            label = re.sub(r"(?<!_)_(?!_)", "", attrs.get("label", "")).replace("__", "_")
            prefix, _, action = attrs.get("action", "").partition(".")
            paths = [path for path in descriptions if ("/window/" in path) == (prefix == "win")]
            if prefix == "win" and len(paths) != 1:
                paths = []
            matches = [(path, descriptions[path][action]) for path in paths if action in descriptions[path]]
            if len(matches) == 1:
                path, (enabled, parameter, state) = matches[0]
                if enabled and not parameter:
                    self.commands[identifier] = (path, action, None)
            return dict(id=identifier, label=label, enabled=identifier in self.commands, visible=True,
                        separator=False, icon="", shortcut="", checked=False, toggle_type="", submenu=False, children=[])

        entries = []
        for section_index, section in enumerate(tree.findall("section")):
            content = [item(element, f"{section_index}:{index}") for index, element in enumerate(section.findall("item"))]
            if content:
                if entries:
                    entries.append(dict(id=-100-section_index, label="", enabled=False, visible=True,
                                        separator=True, icon="", shortcut="", checked=False, submenu=False, children=[]))
                entries.extend(content)
        return [dict(id=-1, label="Menu", enabled=True, visible=True, separator=False, icon="", shortcut="",
                     checked=False, submenu=True, children=entries)]
