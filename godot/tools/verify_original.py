"""Verify the baseline files without touching the original project."""
import hashlib
import json
from pathlib import Path

project = Path(__file__).resolve().parents[1]
root = project.parent
inventory = json.loads((project / "audit/source_inventory.json").read_text())
failures = []
for entry in inventory["files"]:
    path = root / entry["path"]
    if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest() != entry["sha256"]:
        failures.append(entry["path"])
if failures:
    raise SystemExit("Original files changed or missing: " + ", ".join(failures))
print(f"PASS original: {len(inventory['files'])} files unchanged")
