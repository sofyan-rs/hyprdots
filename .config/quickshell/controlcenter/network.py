"""NetworkManager adapter for the control center. Requests arrive over stdin."""
import json
import os
import subprocess
import sys
import tempfile


def fields(line):
    result, token, escaped = [], [], False
    for char in line:
        if escaped:
            token.append(char)
            escaped = False
        elif char == "\\":
            escaped = True
        elif char == ":":
            result.append("".join(token))
            token = []
        else:
            token.append(char)
    if escaped:
        token.append("\\")
    result.append("".join(token))
    return result


def nm(*args, timeout=12):
    process = subprocess.run(["nmcli", *args], text=True, capture_output=True,
                             timeout=timeout, env={**os.environ, "LC_ALL": "C"})
    if process.returncode:
        raise RuntimeError(process.stderr.strip() or "NetworkManager request failed")
    return process.stdout.strip()


def state():
    enabled = nm("radio", "wifi") == "enabled"
    wired = any(fields(line) == ["ethernet", "connected"]
                for line in nm("-t", "-f", "TYPE,STATE", "device", "status").splitlines())
    networks = {}
    for line in nm("-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY,DEVICE", "device", "wifi", "list", "--rescan", "no").splitlines():
        parts = fields(line)
        if len(parts) != 5 or not parts[1]:
            continue
        active, ssid, strength, security, device = parts
        entry = dict(ssid=ssid, signal=int(strength or 0), secured=bool(security and security != "--"),
                     security=security, device=device, inUse=active == "*")
        previous = networks.get(ssid)
        if not previous or (entry["inUse"], entry["signal"]) > (previous["inUse"], previous["signal"]):
            networks[ssid] = entry
    saved = []
    for line in nm("-t", "-f", "NAME,UUID,TYPE,DEVICE", "connection", "show").splitlines():
        parts = fields(line)
        if len(parts) != 4 or parts[2] != "802-11-wireless":
            continue
        name, uuid, _, device = parts
        # A profile can disappear while NetworkManager is refreshing its list.
        try:
            values = nm("-e", "no", "-g", "802-11-wireless.ssid,connection.autoconnect,802-11-wireless-security.key-mgmt", "connection", "show", "uuid", uuid).splitlines()
            saved.append(dict(name=name, uuid=uuid, ssid=values[0] if values else name,
                              autojoin=len(values) > 1 and values[1] == "yes",
                              secured=len(values) > 2 and bool(values[2]),
                              connected=device not in ("", "--")))
        except RuntimeError:
            continue
    ordered = sorted(networks.values(), key=lambda n: (-n["inUse"], -n["signal"], n["ssid"]))
    current = next((n for n in ordered if n["inUse"]), None)
    return dict(enabled=enabled, wired=wired, networks=ordered, saved=saved, current=current)


def action(request):
    kind = request["action"]
    if kind == "radio":
        nm("radio", "wifi", "on" if request["enabled"] else "off")
    elif kind == "scan":
        nm("device", "wifi", "rescan", timeout=20)
    elif kind == "forget":
        nm("connection", "delete", "uuid", request["uuid"])
    elif kind == "autojoin":
        nm("connection", "modify", "uuid", request["uuid"], "connection.autoconnect", "yes" if request["enabled"] else "no")
    elif kind == "disconnect":
        nm("device", "disconnect", request["device"])
    elif kind == "connect":
        password = request.get("password", "")
        uuid = request.get("uuid", "")
        if uuid:
            if password:
                with tempfile.NamedTemporaryFile(mode="w", prefix="quickshell-wifi-") as secret:
                    secret.write("802-11-wireless-security.psk:" + password + "\n")
                    secret.flush()
                    nm("--wait", "30", "connection", "up", "uuid", uuid, "passwd-file", secret.name, timeout=35)
            else:
                nm("--wait", "30", "connection", "up", "uuid", uuid, timeout=35)
        else:
            args = ["--wait", "30", "device", "wifi", "connect", request["ssid"]]
            if request.get("device"):
                args += ["ifname", request["device"]]
            if password:
                args += ["password", password]
            nm(*args, timeout=35)
            device = request.get("device")
            if device:
                uuid = nm("-g", "GENERAL.CON-UUID", "device", "show", device)
        if uuid:
            nm("connection", "modify", "uuid", uuid, "connection.autoconnect", "yes" if request.get("autojoin", True) else "no")
    else:
        raise ValueError("Unsupported network action")


def main():
    request = {}
    try:
        if len(sys.argv) > 1 and sys.argv[1] == "action":
            request = json.loads(sys.stdin.readline())
            action(request)
            print(json.dumps(dict(ok=True)))
        else:
            print(json.dumps(dict(ok=True, state=state())))
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        message = str(error) if not isinstance(error, subprocess.TimeoutExpired) else "NetworkManager timed out. Try again."
        if request.get("password"):
            message = message.replace(request["password"], "••••")
        print(json.dumps(dict(ok=False, error=message)))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
