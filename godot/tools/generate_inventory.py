"""Rebuild the immutable baseline inventory from Git, including original art."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

project = Path(__file__).resolve().parents[1]
root = project.parent
destination = project / "audit/source_inventory.json"
baseline = json.loads(destination.read_text())["base_commit"]
paths = subprocess.check_output(
    ["git", "ls-tree", "-r", "--name-only", "-z", baseline], cwd=root
).decode().split("\0")
files = []
for path in sorted(filter(None, paths)):
    data = subprocess.check_output(["git", "show", f"{baseline}:{path}"], cwd=root)
    imports = re.findall(r'''(?:from\s+|import\s*)['"]([^'"]+)['"]''', data.decode(errors="replace")) if path.endswith(".ts") else []
    files.append({"path": path, "sha256": hashlib.sha256(data).hexdigest(), "imports": imports})
destination.write_text(json.dumps({"base_commit": baseline, "files": files}, indent=2) + "\n")
print(f"Inventoried {len(files)} baseline files from Git, including art and documentation")
