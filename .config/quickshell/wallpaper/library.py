"""Read the wallpaper library and prepare Qt-compatible previews for WebP files."""
import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile

folder = pathlib.Path(sys.argv[1]).expanduser()
cache = pathlib.Path(tempfile.gettempdir()) / "quickshell-wallpaper-previews"
cache.mkdir(mode=0o700, exist_ok=True)
images = []
if folder.is_dir():
    for path in sorted(folder.iterdir(), key=lambda p: p.name):
        if not path.is_file() or path.suffix.lower() not in {".png", ".jpg", ".jpeg", ".webp", ".bmp"}:
            continue
        preview = path
        if path.suffix.lower() == ".webp":
            key = hashlib.sha256(f"{path}:{path.stat().st_mtime_ns}".encode()).hexdigest()
            preview = cache / (key + ".png")
            if not preview.exists():
                result = subprocess.run(["magick", str(path), "-thumbnail", "1300x730", str(preview)], capture_output=True, timeout=30)
                if result.returncode != 0:
                    preview = path
        images.append({"name": path.name, "path": str(path), "preview": str(preview)})
print(json.dumps(images))
