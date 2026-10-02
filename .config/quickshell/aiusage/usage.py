#!/usr/bin/env python3
"""Read Codex account quotas over the local app-server's JSON-RPC transport."""
import datetime as dt
import json
import math
import os
from pathlib import Path
import queue
import shutil
import subprocess
import threading
import time
from zoneinfo import ZoneInfo


def normalize(result):
    buckets = result.get("rateLimitsByLimitId")
    snapshot = (buckets.get("codex") if isinstance(buckets, dict) else None)
    if snapshot is None:
        snapshot = result.get("rateLimits")
        if snapshot and snapshot.get("limitId") not in (None, "codex"):
            snapshot = None
    if not isinstance(snapshot, dict):
        raise ValueError("Codex quota is unavailable for this account.")
    windows = [snapshot.get("primary"), snapshot.get("secondary")]
    data = {}
    for key, minutes in (("session", 300), ("weekly", 10080)):
        window = next((w for w in windows if isinstance(w, dict)
                       and w.get("windowDurationMins") == minutes), None)
        if window is None:
            data[key] = None
            continue
        used = window.get("usedPercent")
        if not isinstance(used, (int, float)) or isinstance(used, bool) or not math.isfinite(used):
            data[key] = None
            continue
        reset = window.get("resetsAt")
        label = None
        if isinstance(reset, (int, float)) and not isinstance(reset, bool) and reset > 0:
            label = dt.datetime.fromtimestamp(reset, ZoneInfo("Asia/Jakarta")).strftime("%d %b %Y · %H:%M")
        data[key] = {"usedPercent": max(0, min(100, used)),
                     "resetsAt": reset, "resetLabel": label}
    if all(value is None for value in data.values()):
        raise ValueError("Session 5-hour and Weekly quotas are unavailable.")
    return {"ok": True, **data, "updatedAt": int(time.time())}


def fetch():
    binary = shutil.which("codex")
    if binary is None:
        fallback = Path.home() / ".local/bin/codex"
        binary = str(fallback) if fallback.is_file() else None
    if binary is None:
        raise ValueError("Codex CLI was not found. Install Codex and sign in.")
    # Keep app-server temporary files inside an allowed runtime directory.
    env = dict(os.environ, TMPDIR=os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
    proc = subprocess.Popen([binary, "app-server"], stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                            text=True, env=env)
    messages = queue.Queue()

    def read():
        for line in proc.stdout:
            try:
                messages.put(json.loads(line))
            except json.JSONDecodeError:
                continue
        messages.put(None)

    threading.Thread(target=read, daemon=True).start()
    deadline = time.monotonic() + 25

    def send(message):
        proc.stdin.write(json.dumps(message) + "\n")
        proc.stdin.flush()

    def response(request_id):
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise TimeoutError
            message = messages.get(timeout=remaining)
            if message is None:
                raise ValueError("Codex app-server stopped before returning usage.")
            if message.get("id") != request_id:
                continue
            if "error" in message:
                code = message["error"].get("code")
                raise ValueError("Could not fetch Codex quota (" + str(code) + "). Check your login and connection.")
            return message.get("result", {})

    try:
        send({"id": 1, "method": "initialize", "params": {
            "clientInfo": {"name": "quickshell_usage", "title": "AI Agent Usage", "version": "1.0"}}})
        response(1)
        send({"method": "initialized", "params": {}})
        send({"id": 2, "method": "account/rateLimits/read"})
        return normalize(response(2))
    finally:
        proc.stdin.close()
        if proc.poll() is None:
            proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        proc.stdout.close()


if __name__ == "__main__":
    try:
        output = fetch()
    except (TimeoutError, queue.Empty):
        output = {"ok": False, "error": "Codex connection timed out. Try refreshing."}
    except ValueError as error:
        output = {"ok": False, "error": str(error)}
    except Exception:
        output = {"ok": False, "error": "Could not read Codex usage. Check your login and connection."}
    print(json.dumps(output))
