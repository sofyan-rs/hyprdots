#!/usr/bin/env python3
"""Stream system stats (or camera usage) as one JSON object per line.

  sysmon.py stats   CPU, memory, disk, network, temperatures, GPU, top processes
  sysmon.py camera  apps holding /dev/video* open
  sysmon.py capslock  Caps Lock state (1/0) on every change
"""
import ctypes
import glob
import json
import os
import shutil
import subprocess
import sys
import time

INTERVAL = 1.5
CLK_TCK = os.sysconf("SC_CLK_TCK")
NCPU = os.cpu_count() or 1


def read(path, default=""):
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return default


def hwmon_temp(name, label=None):
    for d in glob.glob("/sys/class/hwmon/hwmon*"):
        if read(d + "/name").strip() != name:
            continue
        for inp in sorted(glob.glob(d + "/temp*_input")):
            if label and read(inp.replace("_input", "_label")).strip() != label:
                continue
            try:
                return int(read(inp)) / 1000
            except ValueError:
                pass
    return None


def cpu_times():
    parts = read("/proc/stat").split("\n", 1)[0].split()[1:]
    values = list(map(int, parts))
    idle = values[3] + values[4]
    return sum(values), idle


def memory():
    info = {}
    for line in read("/proc/meminfo").splitlines():
        key, _, rest = line.partition(":")
        info[key] = int(rest.split()[0]) * 1024
    total = info.get("MemTotal", 0)
    used = total - info.get("MemAvailable", 0)
    swap_total = info.get("SwapTotal", 0)
    swap_used = swap_total - info.get("SwapFree", 0)
    return {"used": used, "total": total, "swapUsed": swap_used, "swapTotal": swap_total}


def default_iface():
    for line in read("/proc/net/route").splitlines()[1:]:
        fields = line.split()
        if len(fields) > 1 and fields[1] == "00000000":
            return fields[0]
    return None


def net_bytes(iface):
    for line in read("/proc/net/dev").splitlines()[2:]:
        name, _, rest = line.partition(":")
        if name.strip() == iface:
            fields = rest.split()
            return int(fields[0]), int(fields[8])
    return 0, 0


def proc_ticks():
    ticks = {}
    for pid in os.listdir("/proc"):
        if not pid.isdigit():
            continue
        stat = read(f"/proc/{pid}/stat")
        end = stat.rfind(")")
        if end < 0:
            continue
        name = stat[stat.find("(") + 1:end]
        fields = stat[end + 2:].split()
        try:
            ticks[pid] = (name, int(fields[11]) + int(fields[12]), int(fields[21]) * os.sysconf("SC_PAGE_SIZE"))
        except (IndexError, ValueError):
            pass
    return ticks


class _NvmlUtilization(ctypes.Structure):
    _fields_ = [("gpu", ctypes.c_uint), ("memory", ctypes.c_uint)]


class _NvmlMemory(ctypes.Structure):
    _fields_ = [("total", ctypes.c_ulonglong), ("free", ctypes.c_ulonglong), ("used", ctypes.c_ulonglong)]


_nvml = None


def _nvml_device():
    """NVIDIA GPU 0 via libnvidia-ml (ships with the driver), or None."""
    global _nvml
    if _nvml is None:
        try:
            lib = ctypes.CDLL("libnvidia-ml.so.1")
            handle = ctypes.c_void_p()
            if lib.nvmlInit_v2() != 0 or lib.nvmlDeviceGetHandleByIndex_v2(0, ctypes.byref(handle)) != 0:
                raise OSError("NVML unavailable")
            name = ctypes.create_string_buffer(96)
            lib.nvmlDeviceGetName(handle, name, 96)
            _nvml = (lib, handle, name.value.decode(errors="replace"))
        except OSError:
            _nvml = False
    return _nvml or None


def gpu():
    device = _nvml_device()
    if device:
        lib, handle, name = device
        util, mem, temp = _NvmlUtilization(), _NvmlMemory(), ctypes.c_uint()
        if (lib.nvmlDeviceGetUtilizationRates(handle, ctypes.byref(util)) == 0
                and lib.nvmlDeviceGetMemoryInfo(handle, ctypes.byref(mem)) == 0
                and lib.nvmlDeviceGetTemperature(handle, 0, ctypes.byref(temp)) == 0):
            return {"util": util.gpu, "temp": temp.value, "memUsed": mem.used, "memTotal": mem.total, "name": name}
    if not shutil.which("nvidia-smi"):
        return None
    try:
        out = subprocess.run(
            ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,name",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=2).stdout.strip().splitlines()[0]
        util, temp, used, total, name = [v.strip() for v in out.split(",", 4)]
        return {"util": float(util), "temp": float(temp), "memUsed": float(used) * 2**20,
                "memTotal": float(total) * 2**20, "name": name}
    except Exception:
        return None


def stats():
    last_cpu = cpu_times()
    iface = default_iface()
    last_net = net_bytes(iface) if iface else (0, 0)
    last_procs = proc_ticks()
    last_time = time.monotonic()
    # A quick first sample so the view fills in right away.
    delay = 0.3
    while True:
        time.sleep(delay)
        delay = INTERVAL
        now = time.monotonic()
        elapsed = max(0.001, now - last_time)

        total, idle = cpu_times()
        dt, di = total - last_cpu[0], idle - last_cpu[1]
        cpu = 100 * (1 - di / dt) if dt > 0 else 0
        last_cpu = (total, idle)

        current_iface = default_iface()
        if current_iface != iface:
            iface = current_iface
            last_net = net_bytes(iface) if iface else (0, 0)
        rx, tx = net_bytes(iface) if iface else (0, 0)
        net = {"iface": iface or "", "rx": max(0, rx - last_net[0]) / elapsed, "tx": max(0, tx - last_net[1]) / elapsed}
        last_net = (rx, tx)

        procs = proc_ticks()
        # Grouped by name, so multi-process apps show up once.
        by_name = {}
        for pid, (name, ticks, rss) in procs.items():
            entry = by_name.setdefault(name, {"name": name, "cpu": 0.0, "mem": 0})
            entry["mem"] += rss
            prev = last_procs.get(pid)
            if prev and prev[0] == name:
                entry["cpu"] += (ticks - prev[1]) / CLK_TCK / elapsed * 100 / NCPU
        top = sorted((p for p in by_name.values() if p["cpu"] > 0), key=lambda p: p["cpu"], reverse=True)
        last_procs = procs
        last_time = now

        disk = shutil.disk_usage("/")
        print(json.dumps({
            "cpu": cpu,
            "cpuTemp": hwmon_temp("k10temp", "Tctl") or hwmon_temp("coretemp"),
            "mem": memory(),
            "disk": {"used": disk.used, "total": disk.total, "temp": hwmon_temp("nvme", "Composite")},
            "net": net,
            "gpu": gpu(),
            "top": top[:3],
        }), flush=True)


def camera():
    while True:
        apps = set()
        if glob.glob("/dev/video*"):
            for fd_dir in glob.glob("/proc/[0-9]*/fd"):
                try:
                    for fd in os.listdir(fd_dir):
                        if os.readlink(f"{fd_dir}/{fd}").startswith("/dev/video"):
                            apps.add(read(fd_dir[:-2] + "comm").strip())
                            break
                except OSError:
                    continue
        print(json.dumps(sorted(apps)), flush=True)
        time.sleep(3)


def capslock():
    """Print 1/0 whenever any keyboard's Caps Lock LED changes."""
    leds, last, next_scan = [], None, 0
    while True:
        now = time.monotonic()
        if now >= next_scan:  # keyboards come and go (wireless receivers, docks)
            leds = glob.glob("/sys/class/leds/*::capslock/brightness")
            next_scan = now + 5
        state = any(read(path).strip() not in ("", "0") for path in leds)
        if state != last:
            print("1" if state else "0", flush=True)
            last = state
        time.sleep(0.15)


if __name__ == "__main__":
    {"stats": stats, "camera": camera, "capslock": capslock}[sys.argv[1] if len(sys.argv) > 1 else "stats"]()
