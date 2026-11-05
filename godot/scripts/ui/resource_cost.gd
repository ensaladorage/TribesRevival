extends HBoxContainer
## Cost squares are genuinely dynamic data; layout and square template are scenes.

@export var square_scene: PackedScene = preload("res://scenes/ui/CostSquare.tscn")
var _last_cost := {}

func update_cost(cost: Dictionary, enabled: bool) -> void:
	modulate.a = 1.0 if enabled else 0.5
	if cost == _last_cost:
		return
	_last_cost = cost.duplicate()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for resource in ["food", "wood", "stone", "spark", "gold"]:
		for index in int(cost.get(resource, 0)):
			var square := square_scene.instantiate()
			square.theme_type_variation = StringName("Cost" + resource.capitalize())
			add_child(square)
