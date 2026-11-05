extends Node3D
## Minimal migration entry point; simulation never reads scene nodes.

func _ready() -> void:
	$Camera3D.look_at(Vector3(80, 0, 80))
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("26333b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d3e2ef")
	environment.ambient_light_energy = 0.65
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
