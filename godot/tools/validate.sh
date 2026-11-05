#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
engine="${GODOT_BIN:-$project_dir/Godot_v4.7.2-stable_linux.x86_64}"
if [[ ! -x "$engine" ]]; then
  echo 'Set GODOT_BIN to an executable Godot 4 editor.' >&2
  exit 1
fi
mkdir -p "$project_dir/reports"
python3 "$project_dir/tools/verify_original.py"
run_checked() {
  local report="$1"
  shift
  "$engine" --headless --path "$project_dir" "$@" 2>&1 | tee "$project_dir/reports/$report.log"
  if rg -q 'SCRIPT ERROR:|ERROR:|Parse Error:|Failed to load' "$project_dir/reports/$report.log"; then
    echo "Godot reported errors in $report" >&2
    return 1
  fi
}
run_checked import --editor --import
run_checked structure --script res://tools/validate_project.gd
if [[ -f "$project_dir/tests/test_data.gd" ]]; then
  run_checked data --script res://tests/test_data.gd
fi
