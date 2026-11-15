extends SceneTree
const State = preload("res://scripts/simulation/game_state.gd")
const World = preload("res://scenes/WorldView.tscn")
const Conflict = preload("res://scripts/simulation/conflict_system.gd")
const Combat = preload("res://scripts/simulation/combat_rules.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(960, 640)
	var main := preload("res://scenes/main.tscn").instantiate()
	for name in ["Ground", "WorldEnvironment", "Sun"]:
		var node: Node = main.get_node(name)
		main.remove_child(node)
		node.owner = null
		root.add_child(node)
	main.world_view.free()
	main.hud.free()
	main.menus.free()
	main.free()
	var state := State.create_initial("mage-visual")
	state.biomes = []
	state.resources = []
	state.decorations = []
	state.animals = []
	state.weather.clouds = []
	var mage := State.create_unit("mage", "mage", {"x": 80.0, "y": 80.0})
	mage.task.kind = "combat"
	var enemy: Dictionary = state.barbarians[0]
	enemy.position = {"x": 82.0, "y": 78.5}
	state.units = [mage]
	state.barbarians = [enemy]
	Conflict._attack(state, mage, enemy, Combat.minion_attack("mage", 0), "barbarian")
	for effect in state.effects: effect.ageSeconds = 0.11
	var world := World.instantiate()
	root.add_child(world)
	world.setup(state)
	world.sync(state)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9
	var focus := Vector3(81, 0.8, 79.25)
	camera.position = focus + Vector3(1, tan(deg_to_rad(35)) * sqrt(2), 1) * 30
	camera.look_at(focus)
	camera.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/mage-basic-attack.png")
	print("PASS mage attack capture")
	quit()
