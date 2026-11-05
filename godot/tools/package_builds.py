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
source_paths = ["project.godot", "export_presets.cfg", "scripts", "scenes", "assets", "themes", "distribution"]
source_dirty = (
    subprocess.run(["git", "diff", "--quiet", "HEAD", "--", *source_paths], cwd=project).returncode != 0
    or bool(subprocess.check_output(
        ["git", "ls-files", "--others", "--exclude-standard", "--", *source_paths],
        cwd=project, text=True,
    ).strip())
)
records = []
for platform in ("linux", "windows", "web"):
    folder = builds / platform
    for license_file in (project / "distribution").glob("*.txt"):
        shutil.copy2(license_file, folder / license_file.name)
    instructions = {
        "linux": "Extrae el ZIP y ejecuta ./TribesRevival.x86_64 (marca el archivo como ejecutable si hace falta).",
        "windows": "Extrae el ZIP y abre TribesRevival.exe.",
        "web": "Sirve esta carpeta con un servidor HTTP y abre index.html; no se ejecuta desde file://.",
    }
    (folder / "README.txt").write_text(
        "TRIBES REVIVAL - VERSION DE DESARROLLO\n\n" + instructions[platform]
        + "\n\nJuego local para un jugador. Arrastra el tótem para guiar la tribu.\n"
        + "Rueda/+/-: zoom. Esc: pausa. 1/2/3: velocidad. Insert: debug.\n"
        + "Validación manual general en Linux confirmada. Quedan problemas de IA y HUD/UI aplazados por el usuario.\n"
        + "Windows: exportado; su prueba manual está aplazada. No se declara una QA exhaustiva.\n"
        + "Licencias: GODOT_LICENSE.txt y LIBERATION_FONTS_LICENSE.txt.\n"
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
    "validation": "Import/scene/reference checks, isolated menu/input contracts, pure data parity, current saves and Linux menu initialization passed; not exhaustive gameplay QA",
    "manual_validation": {
        "linux": "User confirmed startup, general appearance, editable scenes and absence of reported lag/stuck minions; latest reference-only adjustment initialized headless",
        "windows": "Manual launch deferred by user; export verified only",
        "web": "Initial menu inspected; full gameplay not verified",
        "deferred_by_user": ["HUD/UI issues", "AI issues"],
    },
    "source_inputs_include_local_changes": source_dirty,
    "packages": records,
    "source_inputs": [
        {"path": str(path.relative_to(project)), "sha256": hashlib.file_digest(path.open("rb"), "sha256").hexdigest()}
        for path in sorted([
            project / "project.godot", project / "export_presets.cfg",
            *[path for directory in ("scripts", "scenes", "assets", "themes", "distribution") for path in (project / directory).rglob("*") if path.is_file()],
        ])
    ],
}, indent=2) + "\n")
print("Packaged Linux, Windows and Web development builds with SHA256 manifest")
