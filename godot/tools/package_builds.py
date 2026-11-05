"""Package exported development builds and record their exact content hashes."""
import hashlib
import json
from pathlib import Path
import subprocess
import shutil
import zipfile

project = Path(__file__).resolve().parents[1]
builds = project / "builds"
revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=project, text=True).strip()
records = []
for platform in ("linux", "windows", "web"):
    folder = builds / platform
    shutil.copy2(project / "distribution/GODOT_LICENSE.txt", folder / "GODOT_LICENSE.txt")
    instructions = {
        "linux": "Extrae el ZIP y ejecuta ./TribesRevival.x86_64 (marca el archivo como ejecutable si hace falta).",
        "windows": "Extrae el ZIP y abre TribesRevival.exe.",
        "web": "Sirve esta carpeta con un servidor HTTP y abre index.html; no se ejecuta desde file://.",
    }
    (folder / "README.txt").write_text(
        "TRIBES REVIVAL - VERSION DE DESARROLLO\n\n" + instructions[platform]
        + "\n\nJuego local para un jugador. Arrastra el tótem para guiar la tribu.\n"
        + "Rueda/+/-: zoom. Esc: pausa. 1/2/3: velocidad. Insert: debug.\n"
        + "La revisión visual y del gameplay sigue pendiente.\n"
        + "La licencia de Godot Engine se incluye en GODOT_LICENSE.txt.\n"
    )
    files = sorted(path for path in folder.rglob("*") if path.is_file())
    if not files:
        raise SystemExit("Missing exported files for " + platform)
    archive = builds / f"TribesRevival-{platform}-development.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
        for path in files:
            bundle.write(path, path.relative_to(folder))
    records.append({
        "platform": platform, "archive": archive.name,
        "sha256": hashlib.file_digest(archive.open("rb"), "sha256").hexdigest(),
        "bytes": archive.stat().st_size,
        "files": [{"path": str(path.relative_to(folder)), "sha256": hashlib.file_digest(path.open("rb"), "sha256").hexdigest()} for path in files],
    })
(builds / "manifest.json").write_text(json.dumps({
    "source_commit": revision,
    "development_build": True,
    "validation": "Export only; manual visual/gameplay and Windows launch pending",
    "packages": records,
    "source_inputs": [
        {"path": str(path.relative_to(project)), "sha256": hashlib.file_digest(path.open("rb"), "sha256").hexdigest()}
        for path in sorted([
            project / "project.godot", project / "export_presets.cfg",
            *[path for directory in ("scripts", "scenes", "assets") for path in (project / directory).rglob("*") if path.is_file()],
        ])
    ],
}, indent=2) + "\n")
print("Packaged Linux, Windows and Web development builds with SHA256 manifest")
