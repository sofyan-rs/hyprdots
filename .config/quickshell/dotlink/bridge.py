#!/usr/bin/env python3
"""Bridge between the shell and Dotlink's control socket.

Prints one JSON object per line:
  {"t": "status", "status": {...} | null}   full state; null while Dotlink isn't running
  {"t": "transfer", "transfer": {...}}       a transfer started, progressed or ended
  {"t": "event", "event": {...}}             other one-off events (clipboard, paired, ...)
  {"t": "reply", "seq": n, "reply": {...}}   answer to a request

Reads requests on stdin, one per line: {"seq": n, "req": {"cmd": ...}}.
"""
import json
import os
import socket
import sys
import threading
import time

SOCKET = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "dotlink.sock")
# Events that change what `status` reports; the rest are passed through as they are.
REFRESH = {"devices", "paired", "config", "streams", "cast", "incoming", "incoming_done"}

out_lock = threading.Lock()


def emit(obj):
    with out_lock:
        sys.stdout.write(json.dumps(obj) + "\n")
        sys.stdout.flush()


def call(req, timeout=10):
    """One request, its first reply line."""
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.settimeout(timeout)
        s.connect(SOCKET)
        s.sendall((json.dumps(req) + "\n").encode())
        return json.loads(s.makefile("r", encoding="utf-8").readline())


refresh_wanted = threading.Event()


def refresher():
    # Coalesces bursts of events into one status fetch.
    while True:
        refresh_wanted.wait()
        time.sleep(0.15)
        refresh_wanted.clear()
        try:
            emit({"t": "status", "status": call({"cmd": "status"})})
        except (OSError, ValueError):
            pass


def watcher():
    running = None
    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(SOCKET)
                s.sendall(b'{"cmd":"watch"}\n')
                emit({"t": "status", "status": call({"cmd": "status"})})
                running = True
                for line in s.makefile("r", encoding="utf-8"):
                    try:
                        ev = json.loads(line)
                    except ValueError:
                        continue
                    kind = ev.get("t")
                    if kind == "transfer":
                        ev.pop("t")
                        emit({"t": "transfer", "transfer": ev})
                    else:
                        if kind in REFRESH:
                            refresh_wanted.set()
                        if kind not in ("devices", "config", "streams", "cast"):
                            emit({"t": "event", "event": ev})
        except (OSError, ValueError):
            pass
        if running is not False:
            emit({"t": "status", "status": None})
            running = False
        time.sleep(2)


def handle(line):
    try:
        msg = json.loads(line)
    except ValueError:
        return
    try:
        # Pairing and casting can take a while before the first reply.
        reply = call(msg.get("req", {}), timeout=60)
    except (OSError, ValueError) as e:
        reply = {"error": "Dotlink isn't running" if isinstance(e, (FileNotFoundError, ConnectionRefusedError)) else str(e)}
    emit({"t": "reply", "seq": msg.get("seq"), "reply": reply})
    refresh_wanted.set()


threading.Thread(target=refresher, daemon=True).start()
threading.Thread(target=watcher, daemon=True).start()
for line in sys.stdin:
    if line.strip():
        threading.Thread(target=handle, args=(line,), daemon=True).start()
