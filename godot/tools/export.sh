#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
engine="${GODOT_BIN:-$project_dir/Godot_v4.7.2-stable_linux.x86_64}"
if [[ ! -x "$engine" ]]; then
  echo 'Set GODOT_BIN to an executable Godot 4 editor.' >&2
  exit 1
fi
bash "$project_dir/tools/validate.sh"
mkdir -p "$project_dir/builds/linux" "$project_dir/builds/windows" "$project_dir/builds/web"
export_checked() {
  local preset="$1"
  local platform="$2"
  local output="$3"
  "$engine" --headless --path "$project_dir" --export-release "$preset" "$output" 2>&1 | tee "$project_dir/reports/export-$platform.log"
  if rg -q 'SCRIPT ERROR:|ERROR:|Parse Error:|Failed to load' "$project_dir/reports/export-$platform.log"; then
    echo "Export failed: $platform" >&2
    return 1
  fi
  test -s "$output"
}
export_checked 'Linux x86_64' linux "$project_dir/builds/linux/TribesRevival.x86_64"
export_checked 'Windows x86_64' windows "$project_dir/builds/windows/TribesRevival.exe"
export_checked 'Web' web "$project_dir/builds/web/index.html"
"$project_dir/builds/linux/TribesRevival.x86_64" --headless --quit-after 1 --audio-driver Dummy 2>&1 | tee "$project_dir/reports/linux-startup.log"
if rg -q 'SCRIPT ERROR:|ERROR:|Parse Error:|Failed to load' "$project_dir/reports/linux-startup.log"; then
  echo 'Exported Linux build failed to initialize its main menu.' >&2
  exit 1
fi
python3 "$project_dir/tools/package_builds.py"
