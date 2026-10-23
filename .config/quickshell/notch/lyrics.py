#!/usr/bin/env python3
"""Look up lyrics for a track on lrclib.net, with a local cache.

  lyrics.py <title> <artist> [album] [duration-seconds]

Prints one JSON object:
  {"status": "synced", "lines": [{"t": 12.3, "text": "..."}], "plain": "..."}
  {"status": "plain", "plain": "..."}
  {"status": "instrumental"} or {"status": "missing"}
"""
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API = "https://lrclib.net/api"
USER_AGENT = "quickshell-notch (personal desktop shell)"
CACHE_DIR = os.path.join(os.environ.get("XDG_CACHE_HOME", os.path.expanduser("~/.cache")), "quickshell", "lyrics")
# Misses are retried after a day, in case lyrics get added upstream.
MISS_TTL = 24 * 3600
# Bumped when the lookup gets smarter, so older misses are retried.
CACHE_VERSION = 2
TIMESTAMP = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\]")
JAPANESE = re.compile(r"[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff]")
VENV = os.path.expanduser("~/.local/share/quickshell/venv")


def romanizer():
    """pykakasi from the shell's own venv (it is not packaged for Fedora); None if missing."""
    try:
        import pykakasi
    except ImportError:
        import glob
        sys.path.extend(glob.glob(os.path.join(VENV, "lib", "python*", "site-packages")))
        try:
            import pykakasi
        except ImportError:
            return None
    kakasi = pykakasi.kakasi()

    def to_romaji(text):
        words = [item["hepburn"] or item["orig"] for item in kakasi.convert(text)]
        romaji = re.sub(r"\s+", " ", " ".join(words)).strip()
        return re.sub(r"\s+([!?,.、。！？])", r"\1", romaji)
    return to_romaji


def add_romaji(result):
    """Romaji for Japanese lines, computed on the way out so cached lyrics get it too."""
    lines = result.get("lines") or []
    if not any(JAPANESE.search(line["text"]) for line in lines):
        return result
    to_romaji = romanizer()
    if not to_romaji:
        return result
    for line in lines:
        if JAPANESE.search(line["text"]):
            line["romaji"] = to_romaji(line["text"])
    result["hasRomaji"] = True
    return result


def request(path, params):
    url = f"{API}/{path}?{urllib.parse.urlencode(params)}"
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=8) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def parse_synced(lrc):
    lines = []
    for raw in lrc.splitlines():
        stamps = TIMESTAMP.findall(raw)
        text = TIMESTAMP.sub("", raw).strip()
        for minutes, seconds in stamps:
            lines.append({"t": int(minutes) * 60 + float(seconds), "text": text})
    lines.sort(key=lambda line: line["t"])
    return lines


def to_result(record):
    if not record:
        return {"status": "missing"}
    if record.get("instrumental"):
        return {"status": "instrumental"}
    synced = record.get("syncedLyrics") or ""
    plain = record.get("plainLyrics") or ""
    if synced.strip():
        return {"status": "synced", "lines": parse_synced(synced), "plain": plain}
    if plain.strip():
        return {"status": "plain", "plain": plain}
    return {"status": "missing"}


def title_variants(title):
    """Players often decorate titles: "好きだから。 - Sukidakara", "Song (Official Video)", "Song feat. X"."""
    variants = [title]
    cleaned = re.sub(r"\s*[\(\[【][^\)\]】]*(official|video|mv|lyric|audio|music|ver|version|remaster)[^\)\]】]*[\)\]】]", "", title, flags=re.I)
    cleaned = re.sub(r"\s+(feat\.?|ft\.?)\s+.*$", "", cleaned, flags=re.I).strip()
    variants.append(cleaned)
    for part in re.split(r"\s+[-–—/|]\s+", cleaned):
        variants.append(part.strip())
    seen, unique = set(), []
    for v in variants:
        if v and v.lower() not in seen:
            seen.add(v.lower())
            unique.append(v)
    return unique


def pick(results, duration):
    """Closest duration wins, synced lyrics preferred; reject clear mismatches."""
    usable = [r for r in results if r.get("syncedLyrics") or r.get("plainLyrics") or r.get("instrumental")]
    if not usable:
        return None
    if duration:
        usable = [r for r in usable if not r.get("duration") or abs(r["duration"] - duration) <= 15]
        if not usable:
            return None
    return min(usable, key=lambda r: (not r.get("syncedLyrics"),
                                      abs((r.get("duration") or duration) - duration) if duration else 0))


def lookup(title, artist, album, duration):
    titles = title_variants(title)
    exact = {"track_name": title, "artist_name": artist}
    if album:
        exact["album_name"] = album
    if duration:
        exact["duration"] = round(duration)
    record = request("get", exact)
    if record:
        return to_result(record)
    for name in titles:
        best = pick(request("search", {"track_name": name, "artist_name": artist}) or [], duration)
        if best:
            return to_result(best)
    # Last resort: free-text search, which also matches artists written differently (Yuika vs 『ユイカ』).
    for name in titles:
        best = pick(request("search", {"q": f"{name} {artist}"}) or [], duration)
        if best:
            return to_result(best)
    return {"status": "missing"}


def main():
    title = sys.argv[1] if len(sys.argv) > 1 else ""
    artist = sys.argv[2] if len(sys.argv) > 2 else ""
    album = sys.argv[3] if len(sys.argv) > 3 else ""
    try:
        duration = float(sys.argv[4]) if len(sys.argv) > 4 else 0
    except ValueError:
        duration = 0
    if not title or not artist:
        print(json.dumps({"status": "missing"}))
        return

    key = hashlib.sha1(f"{title}\n{artist}".lower().encode()).hexdigest()
    cache = os.path.join(CACHE_DIR, key + ".json")
    try:
        with open(cache) as f:
            cached = json.load(f)
        fresh_miss = cached.get("v") == CACHE_VERSION and time.time() - cached["at"] < MISS_TTL
        if cached["result"]["status"] != "missing" or fresh_miss:
            print(json.dumps(add_romaji(cached["result"])))
            return
    except (OSError, ValueError, KeyError):
        pass

    try:
        result = lookup(title, artist, album, duration)
    except Exception as e:  # offline, timeout, bad response: try again next time
        print(json.dumps({"status": "error", "error": str(e)}))
        return
    os.makedirs(CACHE_DIR, exist_ok=True)
    with open(cache, "w") as f:
        json.dump({"v": CACHE_VERSION, "at": time.time(), "result": result}, f)
    print(json.dumps(add_romaji(result)))


if __name__ == "__main__":
    main()
