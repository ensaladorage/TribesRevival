#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
engine="${GODOT_BIN:-$project_dir/Godot_v4.7.2-stable_linux.x86_64}"
if [[ ! -x "$engine" ]]; then
  echo 'Set GODOT_BIN to an executable Godot 4 editor.' >&2
  exit 1
fi
mkdir -p "$project_dir/reports"
touch "$project_dir/reports/.gdignore"
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
run_checked respawn-interpolation --script res://tests/test_respawn_interpolation.gd
run_checked island-routes --script res://tests/test_island_routes.gd
run_checked tree-resources --script res://tests/test_tree_resources.gd
run_checked cloud-visuals --script res://tests/test_cloud_visuals.gd
run_checked bush-occlusion --script res://tests/test_bush_occlusion.gd
run_checked natural-visibility --script res://tests/test_natural_visibility.gd
run_checked world-decorations --script res://tests/test_world_decorations.gd
run_checked menu-callbacks --script res://tests/test_menu_callbacks.gd
run_checked placement-input --script res://tests/test_placement_input.gd
run_checked minion-drag-input --script res://tests/test_minion_drag_input.gd
run_checked minion-carry --script res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests/gdunit/combat/test_minion_carry.gd --ignoreHeadlessMode
if [[ -f "$project_dir/tests/test_data.gd" ]]; then
  run_checked data --script res://tests/test_data.gd
fi

run_checked tactical-behavior --script res://tests/test_tactical_behavior.gd
run_checked mage-combat --script res://tests/test_mage_combat.gd
run_checked tactical-edges --script res://tests/test_tactical_edges.gd
run_checked civil-flee --script res://tests/test_civil_flee.gd
