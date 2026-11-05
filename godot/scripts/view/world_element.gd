@tool
extends Node3D
## Interchangeable appearance only: a model, Sprite3D or AnimatedSprite3D scene.

@export var appearance_override: PackedScene:
	set(value):
		appearance_override = value
		if is_node_ready():
			_refresh_appearance()
@export var visual_scale := Vector3.ONE:
	set(value):
		visual_scale = value
		if is_node_ready():
			$Visual.scale = value
@export var visual_offset := Vector3.ZERO:
	set(value):
		visual_offset = value
		if is_node_ready():
			$Visual.position = value
var _replacement: Node3D

func _ready() -> void:
	$Visual.scale = visual_scale
	$Visual.position = visual_offset
	_refresh_appearance()

func _refresh_appearance() -> void:
	if is_instance_valid(_replacement):
		_replacement.get_parent().remove_child(_replacement)
		_replacement.queue_free()
		_replacement = null
	$Visual/Default.visible = true
	if appearance_override == null:
		return
	var instance := appearance_override.instantiate()
	if instance is Node3D:
		_replacement = instance
		$Visual.add_child(instance)
		$Visual/Default.hide()
	else:
		instance.free()
		push_warning("Appearance override must have a Node3D root")
