#!/usr/bin/env python3
"""Read AI agent quotas: Codex via its local app-server, Claude via the OAuth usage API."""
import datetime as dt
import json
import math
import os
from pathlib import Path
import queue
import shutil
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from zoneinfo import ZoneInfo


TZ = ZoneInfo("Asia/Jakarta")
CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "quickshell"
MIN_AGE = 120  # seconds a cached result is reused without asking the server again


class RateLimited(Exception):
    def __init__(self, retry_after):
        self.retry_after = retry_after


def window_data(used, reset):
    label = None
    if isinstance(reset, (int, float)) and not isinstance(reset, bool) and reset > 0:
        label = dt.datetime.fromtimestamp(reset, TZ).strftime("%d %b %Y · %H:%M")
    return {"usedPercent": max(0, min(100, used)), "resetsAt": reset, "resetLabel": label}


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
        data[key] = window_data(used, window.get("resetsAt"))
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


def parse_time(value):
    if not isinstance(value, str):
        return None
    try:
        return int(dt.datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp())
    except ValueError:
        return None


def fetch_claude():
    path = Path(os.environ.get("CLAUDE_CONFIG_DIR", Path.home() / ".claude")) / ".credentials.json"
    try:
        oauth = json.loads(path.read_text()).get("claudeAiOauth") or {}
    except (OSError, json.JSONDecodeError):
        oauth = {}
    token = oauth.get("accessToken")
    if not token:
        raise ValueError("Claude login not found. Run `claude` and sign in.")
    expires = oauth.get("expiresAt")
    if isinstance(expires, (int, float)) and expires / 1000 < time.time():
        raise ValueError("Claude login expired. Open `claude` to refresh it.")
    request = urllib.request.Request("https://api.anthropic.com/api/oauth/usage", headers={
        "Authorization": "Bearer " + token,
        "anthropic-beta": "oauth-2025-04-20",
        "User-Agent": "quickshell-usage/1.0"})
    try:
        with urllib.request.urlopen(request, timeout=20) as reply:
            result = json.load(reply)
    except urllib.error.HTTPError as error:
        if error.code == 429:
            try:
                retry = int(error.headers.get("Retry-After", ""))
            except ValueError:
                retry = 300
            raise RateLimited(max(60, retry))
        if error.code in (401, 403):
            raise ValueError("Claude login rejected. Open `claude` to refresh it.")
        raise ValueError("Could not fetch Claude quota (" + str(error.code) + ").")
    except (urllib.error.URLError, OSError):
        raise TimeoutError
    limits = result.get("limits") if isinstance(result.get("limits"), list) else []
    data = {}
    for key, field in (("session", "five_hour"), ("weekly", "seven_day")):
        window = result.get(field)
        used = window.get("utilization") if isinstance(window, dict) else None
        reset = window.get("resets_at") if isinstance(window, dict) else None
        if used is None:
            limit = next((l for l in limits if isinstance(l, dict) and l.get("group") == key), None)
            if limit:
                used, reset = limit.get("percent"), limit.get("resets_at")
        if not isinstance(used, (int, float)) or isinstance(used, bool) or not math.isfinite(used):
            data[key] = None
            continue
        data[key] = window_data(used, parse_time(reset))
    if all(value is None for value in data.values()):
        raise ValueError("Session 5-hour and Weekly quotas are unavailable.")
    return {"ok": True, **data, "updatedAt": int(time.time())}


def load_cache(path):
    try:
        data = json.loads(path.read_text())
        return data if isinstance(data, dict) else {}
    except (OSError, json.JSONDecodeError):
        return {}


def save_cache(path, data):
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data))
    except OSError:
        pass


def wait_label(seconds):
    minutes = max(1, math.ceil(seconds / 60))
    return str(minutes) + " min"


if __name__ == "__main__":
    provider = sys.argv[1] if len(sys.argv) > 1 else "codex"
    force = "--force" in sys.argv
    name = "Claude" if provider == "claude" else "Codex"
    cache_path = CACHE_DIR / ("aiusage-" + provider + ".json")
    cache = load_cache(cache_path)
    last = cache.get("last") if isinstance(cache.get("last"), dict) else None
    now = time.time()
    output = None
    if last and not force and now - last.get("updatedAt", 0) < MIN_AGE:
        output = last
    elif cache.get("retryAt", 0) > now:
        output = {"ok": False, "error": name + " rate limited. Retrying in " + wait_label(cache["retryAt"] - now) + "."}
    else:
        try:
            output = fetch_claude() if provider == "claude" else fetch()
            cache = {"last": output}
        except RateLimited as limited:
            cache["retryAt"] = now + limited.retry_after
            output = {"ok": False, "error": name + " rate limited. Retrying in " + wait_label(limited.retry_after) + "."}
        except (TimeoutError, queue.Empty):
            output = {"ok": False, "error": name + " connection timed out. Try refreshing."}
        except ValueError as error:
            output = {"ok": False, "error": str(error)}
        except Exception:
            output = {"ok": False, "error": "Could not read " + name + " usage. Check your login and connection."}
        save_cache(cache_path, cache)
    if not output.get("ok") and last:
        output = {**output, "session": last.get("session"), "weekly": last.get("weekly"), "updatedAt": last.get("updatedAt")}
    print(json.dumps(output))
