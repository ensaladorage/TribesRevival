extends CanvasLayer
## Screen-space HP data presentation. Shape, colors and size remain scene/theme assets.

@export var pip_scene: PackedScene = preload("res://scenes/ui/HealthPip.tscn")
@export var enemy := false
@export var pip_size := Vector2(9, 9)
var _count := -1
var _health := -1
var _pips: Array[Control] = []

func present(health: int, maximum: int, screen_position: Vector2) -> void:
	if _count != maximum:
		for child in _pips:
			$Pips.remove_child(child)
			child.queue_free()
		_pips.clear()
		for index in maximum:
			var pip := pip_scene.instantiate() as Control
			pip.custom_minimum_size = pip_size
			$Pips.add_child(pip)
			_pips.append(pip)
		_count = maximum
		_health = -1
	if _health != health:
		for index in _pips.size():
			_pips[index].theme_type_variation = StringName(("Enemy" if enemy else "Ally") + ("Filled" if index < health else "Empty"))
		_health = health
	$Pips.position = screen_position - Vector2(maximum * pip_size.x / 2.0, 0)
