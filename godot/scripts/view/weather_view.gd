@tool
extends "res://scripts/view/world_element.gd"
## Visual phase only; rain/replenishment rules remain in the simulation.

@export var sway_amount := 0.035
@export var rain_speed := 0.8
@export_range(3.0, 50.0, 0.1) var cloud_height := 15.0:
	set(value):
		cloud_height = value
		if is_node_ready():
			_apply_height()

func _ready() -> void:
	super._ready()
	_apply_height()

func _apply_height() -> void:
	# Preserve the editable satellite positions around the original 13.4 m center.
	$Visual/Default/Clouds.position.y = cloud_height - 13.4

func present(cloud: Dictionary) -> void:
	rotation.y = sin(cloud.phaseElapsedSeconds * 0.7) * sway_amount
	var rain := $Visual/Default/Rain
	rain.visible = cloud.phase == "raining"
	if not rain.visible:
		return
	var start := cloud_height - 1.2
	var distance := maxf(start - 0.9, 0.1)
	# Original 11.3 m range * rain_speed cycles/sec: same physical falling speed.
	var cycles_per_second := rain_speed * 11.3 / distance
	for index in rain.get_child_count():
		var progress := fposmod(cloud.phaseElapsedSeconds * cycles_per_second + float(index) / rain.get_child_count(), 1.0)
		rain.get_child(index).position.y = start - progress * distance
