extends SceneTree
const State = preload("res://scripts/simulation/game_state.gd")
const World = preload("res://scenes/WorldView.tscn")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := World.instantiate()
	root.add_child(world)
	for scene in world.cloud_variants:
		var view: Node3D = scene.instantiate()
		root.add_child(view)
		var sizes := {"Large": 0, "Medium": 0, "Small": 0}
		for sprite in view.get_node("Visual/Default/Clouds").get_children():
			for size in sizes:
				if str(sprite.name).begins_with(size):
					sizes[size] += 1
			_check(sprite is Sprite3D and sprite.texture != null and sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Textured nearest sprites")
			_check(not sprite.no_depth_test and sprite.render_priority == 0, "Natural depth")
			_check(sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD and is_equal_approx(sprite.alpha_scissor_threshold, 0.5), "Discard painted shadow, preserve opaque body")
			_check(sprite.position.distance_to(Vector3(0, 13.4, 0)) <= 7, "Satellites stay close to large cloud")
		_check(sizes.Large == 1 and sizes.Medium >= 1 and sizes.Medium <= 2 and sizes.Small >= 1 and sizes.Small <= 3, "One large, one/two medium, one/three small")
		var shadow: MeshInstance3D = view.get_node("GroundShadow")
		_check(is_equal_approx(shadow.position.y, 0.08) and shadow.mesh.size == Vector2(14, 9), "Shadow clears biome surface and has editable footprint")
		_check(is_equal_approx(shadow.material_override.get_shader_parameter("opacity"), 0.12), "Subtle shadow opacity")
		_check(is_equal_approx(view.get_node("Visual/Default/Clouds").position.y + 13.4, 15.0), "Cloud group at 15 metres")
		view.cloud_height = 25.0
		_check(is_equal_approx(view.get_node("Visual/Default/Clouds").position.y + 13.4, 25.0), "Inspector height updates group")
		view.cloud_height = 15.0
		view.position = Vector3(10, 0, 20)
		_check(shadow.global_position.is_equal_approx(Vector3(10, 0.08, 20)), "Ground shadow follows horizontal translation")
		_check(view.find_children("Puff*", "MeshInstance3D", true, false).is_empty(), "No old cloud meshes")
		view.present({"phase": "approaching", "phaseElapsedSeconds": 0.0})
		_check(not view.get_node("Visual/Default/Rain").visible, "Dry phase hides rain")
		view.present({"phase": "raining", "phaseElapsedSeconds": 0.5})
		_check(view.get_node("Visual/Default/Rain").visible, "Raining phase shows existing rain")
		var before: float = view.get_node("Visual/Default/Rain").get_child(0).position.y
		view.present({"phase": "raining", "phaseElapsedSeconds": 0.7})
		_check(not is_equal_approx(before, view.get_node("Visual/Default/Rain").get_child(0).position.y), "Rain still animates")
		var after: float = view.get_node("Visual/Default/Rain").get_child(0).position.y
		_check(is_equal_approx(before - after, 11.3 * 0.8 * 0.2), "Rain preserves physical falling speed")
		view.present({"phase": "raining", "phaseElapsedSeconds": 0.0})
		_check(is_equal_approx(view.get_node("Visual/Default/Rain").get_child(0).position.y, 13.8), "Rain starts below elevated cloud")
		view.free()
	var state := State.create_initial("cloud-visuals")
	state.weather.clouds.clear()
	for index in 48:
		state.weather.clouds.append({"id": "cloud-%d" % index, "position": {"x": 80, "y": 80}, "phase": "approaching", "phaseElapsedSeconds": 0.0})
	var original := JSON.stringify(state)
	world.setup(state)
	var first := _variants(world, state)
	_check(first.values().reduce(func(acc, value): acc[value] = true; return acc, {}).size() == 4, "All four compositions sampled")
	world.setup(JSON.parse_string(original))
	_check(first == _variants(world, state), "Stable variants after rebuild and JSON load")
	_check(original == JSON.stringify(state), "No simulation or save mutation")
	world.free()
	print("%s cloud visuals: %d checks, four compositions and 48 stable choices" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _variants(world: Node3D, state: Dictionary) -> Dictionary:
	var result := {}
	for cloud in state.weather.clouds:
		result[cloud.id] = world._views[cloud.id].scene_file_path
	return result

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)
