extends "res://scripts/view/world_element.gd"
## Draws the flight from simulation time.

const Work = preload("res://scripts/simulation/work_system.gd")
const TerrainView = preload("res://scripts/view/terrain_projection.gd")

@export var launch_height := 1.2
@export var first_bounce_height := 0.35
@export var second_bounce_height := 0.12
@export var settled_lift := 0.10

func present_drop(drop: Dictionary, render_tick: float, terrain: Array) -> void:
	var landing: Dictionary = drop.position
	var elapsed := render_tick - float(drop.get("launchTick", render_tick - Work.DROP_SETTLE_TICKS))
	if not drop.has("launchOrigin") or elapsed >= Work.DROP_SETTLE_TICKS:
		position = TerrainView.world(landing, terrain)
		$Visual.position = visual_offset + Vector3.UP * settled_lift
		return

	var first_contact := Work.DROP_FLIGHT_TICKS
	var second_contact := first_contact + Work.DROP_FIRST_BOUNCE_TICKS
	var progress: float
	var height: float
	if elapsed < first_contact:
		var phase := clampf(elapsed / first_contact, 0.0, 1.0)
		progress = phase * 0.80
		height = _arc(phase, launch_height)
	elif elapsed < second_contact:
		var phase := (elapsed - first_contact) / Work.DROP_FIRST_BOUNCE_TICKS
		progress = lerpf(0.80, 0.95, phase)
		height = _arc(phase, first_bounce_height)
	else:
		var phase := (elapsed - second_contact) / Work.DROP_SECOND_BOUNCE_TICKS
		progress = lerpf(0.95, 1.0, phase)
		height = _arc(phase, second_bounce_height)

	var origin: Dictionary = drop.launchOrigin
	position = TerrainView.world({"x": lerpf(origin.x, landing.x, progress), "y": lerpf(origin.y, landing.y, progress)}, terrain)
	$Visual.position = visual_offset + Vector3.UP * height

static func _arc(phase: float, height: float) -> float:
	return 4.0 * height * phase * (1.0 - phase)
