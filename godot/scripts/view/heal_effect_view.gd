@tool
extends "res://scripts/view/world_element.gd"
## Editable cross meshes, positioned from the existing effect age.

@export var rise_height := 1.15
@export var spread := 0.24

func present(effect: Dictionary, point: Dictionary) -> void:
	position = Vector3(point.x, 0, point.y)
	var progress := clampf(effect.ageSeconds / effect.durationSeconds, 0, 1)
	var crosses := $Visual.get_children()
	for index in crosses.size():
		crosses[index].position = Vector3((index - 1) * spread, 0.62 + progress * rise_height + index * 0.08, 0)
		crosses[index].scale = Vector3.ONE * (1 - progress * 0.25)
