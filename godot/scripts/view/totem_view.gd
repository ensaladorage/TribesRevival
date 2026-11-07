@tool
extends MeshInstance3D
## El material se edita desde la raíz, sin modificar la escena importada.

@export var model_material: StandardMaterial3D:
	set(value):
		model_material = value
		_apply_material()
@export var carried_color := Color("e0e2deff")

func _ready() -> void:
	_apply_material()

func _apply_material() -> void:
	var model := get_node_or_null("3D Totem/tripo_node_0aac9488-70dc-4007-9213-d5f963b1f7dd") as MeshInstance3D
	if model != null:
		model.material_override = model_material

func present(carried: bool) -> void:
	var model := get_node_or_null("3D Totem/tripo_node_0aac9488-70dc-4007-9213-d5f963b1f7dd") as MeshInstance3D
	if model == null:
		return
	if carried and model_material != null:
		var carried_material := model_material.duplicate() as StandardMaterial3D
		carried_material.albedo_color = carried_color
		model.material_override = carried_material
	else:
		model.material_override = model_material
