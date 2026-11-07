@tool
extends "res://scripts/view/world_element.gd"
## Follow the rendered actor; the sprite animation and transform live in the scene.

func present(_effect: Dictionary, point: Dictionary) -> void:
	position = Vector3(point.x, 0, point.y)
