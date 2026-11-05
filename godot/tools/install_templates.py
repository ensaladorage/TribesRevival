"""Install verified official Godot 4.7.2 desktop/web export templates locally."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import urllib.request
import zipfile

VERSION = "4.7.2.stable"
URL = "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
SHA256 = "f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011"
project = Path(__file__).resolve().parents[1]
cache = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "tribes-revival"
cache.mkdir(parents=True, exist_ok=True)
archive = cache / "Godot_v4.7.2-stable_export_templates.tpz"
if not archive.exists():
    temporary = archive.with_suffix(".tpz.part")
    print("Downloading official Godot export templates (about 1.19 GB)", flush=True)
    with urllib.request.urlopen(URL, timeout=60) as response, temporary.open("wb") as output:
        shutil.copyfileobj(response, output, length=1024 * 1024)
    temporary.rename(archive)
digest = hashlib.file_digest(archive.open("rb"), "sha256").hexdigest()
if digest != SHA256:
    raise SystemExit("Export template SHA256 mismatch; archive was not installed")
data_root = Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
destination = data_root / "godot/export_templates" / VERSION
destination.mkdir(parents=True, exist_ok=True)
records = []
with zipfile.ZipFile(archive) as bundle:
    version = bundle.read("templates/version.txt").decode().strip()
    if version != VERSION:
        raise SystemExit(f"Unexpected template version: {version}")
    names = [name for name in bundle.namelist() if name.startswith("templates/") and (
        name.rsplit("/", 1)[-1] in {"version.txt", "linux_debug.x86_64", "linux_release.x86_64", "windows_debug_x86_64.exe", "windows_release_x86_64.exe"}
        or name.rsplit("/", 1)[-1].startswith("web_")
    ) and not name.endswith("/")]
    for name in names:
        target = destination / name.rsplit("/", 1)[-1]
        with bundle.open(name) as source, target.open("wb") as output:
            shutil.copyfileobj(source, output)
        if target.name.startswith("linux_"):
            target.chmod(0o755)
        records.append({"name": target.name, "sha256": hashlib.file_digest(target.open("rb"), "sha256").hexdigest(), "bytes": target.stat().st_size})
(project / "audit/export_templates.json").write_text(json.dumps({"version": VERSION, "source": URL, "archive_sha256": digest, "files": records}, indent=2) + "\n")
print(f"Installed and verified {len(records)} desktop/web template files for {VERSION}", flush=True)
