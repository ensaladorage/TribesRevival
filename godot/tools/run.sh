#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
engine="${GODOT_BIN:-$project_dir/Godot_v4.7.2-stable_linux.x86_64}"
if [[ ! -x "$engine" ]]; then
  echo 'Set GODOT_BIN to an executable Godot 4 editor.' >&2
  exit 1
fi
exec "$engine" --path "$project_dir" "$@"
