extends Node3D
## Feedback visual al transportar el tótem.

@export var carried_color := Color("e0e2deff")
var _rest_color: Color

func _ready() -> void:
	_rest_color = $Sprite.modulate

func present(carried: bool) -> void:
	$Sprite.modulate = carried_color if carried else _rest_color
