extends SceneTree
const State = preload("res://scripts/simulation/game_state.gd")
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	main.menus.hide()
	main.hud.hide()
	main.get_node("Overlay").hide()
	var state: Dictionary = main.session.state
	state.resources = []
	state.biomes = []
	state.decorations = []
	state.animals = []
	state.units = []
	var enemy: Dictionary = state.barbarians[0].duplicate(true)
	enemy.position = {"x": 85.0, "y": 80.0}
	enemy.spawnPosition = enemy.position.duplicate()
	enemy.health = 40
	enemy.maxHealth = 40
	state.barbarians = [enemy]
	for i in 6:
		var unit = State.create_unit("review-%s" % i, "guardian" if i < 2 else "gatherer", {"x": 82.5 + (i % 2) * 1.3, "y": 78.0 + floori(i / 2.0) * 1.4})
		state.units.append(unit)
	main.world_view.setup(state)
	main.camera.zoom = 0.4
	main.camera.apply_transform()
	main.totem_view.position = Vector3(80, 2, 80)
	DirAccess.make_dir_recursive_absolute("res://reports/tactics")
	for sample in 5:
		if sample > 0:
			for tick in 40: main.session.advance(0.05)
		main.world_view.sync(state, main.session.previous_positions, 1.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var picture = root.get_texture().get_image()
		picture.save_png("res://reports/tactics/mixed-%s.png" % sample)
		print("Captured ", sample, " tick ", state.tick)
	main.free()
	quit()
