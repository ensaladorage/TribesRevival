extends MeshInstance3D
## The editable rest material remains the source of truth; carrying is feedback.

@export var carried_color := Color("f1b35c")
var _rest_material: Material
var _carried_material: StandardMaterial3D

func _ready() -> void:
	_rest_material = material_override
	if _rest_material is StandardMaterial3D:
		_carried_material = _rest_material.duplicate()
		_carried_material.albedo_color = carried_color

func present(carried: bool) -> void:
	material_override = _carried_material if carried and _carried_material != null else _rest_material
