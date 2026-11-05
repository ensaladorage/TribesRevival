@tool
extends "res://scripts/view/world_element.gd"
## Visual phase only; rain/replenishment rules remain in the simulation.

@export var sway_amount := 0.035
@export var rain_speed := 0.8

func present(cloud: Dictionary) -> void:
	rotation.y = sin(cloud.phaseElapsedSeconds * 0.7) * sway_amount
	var rain := $Visual/Default/Rain
	rain.visible = cloud.phase == "raining"
	if not rain.visible:
		return
	for index in rain.get_child_count():
		var progress := fposmod(cloud.phaseElapsedSeconds * rain_speed + float(index) / rain.get_child_count(), 1.0)
		rain.get_child(index).position.y = maxf(12.2 - progress * 11.3, 0.55)
