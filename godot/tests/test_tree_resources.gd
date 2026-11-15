extends SceneTree
## World guarantees, appearance isolation, and actual harvest/rain lifecycle.
const Catalog = preload("res://scripts/simulation/world_catalog.gd")
const State = preload("res://scripts/simulation/game_state.gd")
const World = preload("res://scenes/WorldView.tscn")
const Work = preload("res://scripts/simulation/work_system.gd")
const Move = preload("res://scripts/simulation/minion_movement.gd")
const Weather = preload("res://scripts/simulation/weather_system.gd")
const Saves = preload("res://scripts/persistence/save_repository.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for index in 64:
		var seed_text := "tree-biomes-%d" % index
		var blueprint := Catalog.create_blueprint(seed_text)
		_check(blueprint == Catalog.create_blueprint(seed_text), "Repeatable blueprint")
		_check(blueprint.biomes.filter(func(b): return not b.isDecorativeOnly).size() == 10, "Ten resource biomes")
		_check(blueprint.biomes.filter(func(b): return b.id == "forest").size() >= 3, "At least three forests")
		var ids := {}
		for node in blueprint.resources:
			_check(not ids.has(node.id), "Unique resource IDs")
			ids[node.id] = true
			var biome: Dictionary = blueprint.biomes.filter(func(b): return b.instanceId == node.biomeInstanceId)[0]
			_check(Vector2(node.position.x - biome.region.x, node.position.y - biome.region.y).length() <= biome.region.size / 2.0 + 0.02, "Resources inside biome")
		for biome in blueprint.biomes:
			if biome.id == "meadow":
				var nodes: Array = blueprint.resources.filter(func(n): return n.biomeInstanceId == biome.instanceId)
				_check(nodes.any(func(n): return n.source == "tree"), "Meadow has wood")
				_check(nodes.any(func(n): return n.source == "berry-bush"), "Meadow retains berries")
			for other in blueprint.biomes:
				if other.instanceId == biome.instanceId:
					continue
				_check(Vector2(biome.region.x - other.region.x, biome.region.y - other.region.y).length() + 0.02 >= (biome.region.size + other.region.size) / 2.0 + 0.5, "No biome overlap")
	var world := World.instantiate()
	root.add_child(world)
	var variants := {}
	for biome in ["forest", "meadow", "rocky"]:
		for index in 32:
			var resource := {"source": "tree", "id": "test-%d" % index, "biome": biome, "position": {"x": 10, "y": 10}}
			var original := JSON.stringify(resource)
			var first: Node3D = world._create_resource(resource, "tree-variants")
			var second: Node3D = world._create_resource(JSON.parse_string(original), "tree-variants")
			_check(first.scene_file_path == second.scene_file_path, "Stable variant after JSON")
			var texture: String = first.get_node("Visual/Default/Sprite").sprite_frames.get_frame_texture("idle", 0).atlas.resource_path
			_check(texture.get_file() in (["Tree3.png", "Tree4.png"] if biome == "meadow" else ["Tree1.png", "Tree2.png"]), "Correct biome variants")
			variants[texture] = true
			_check(original == JSON.stringify(resource), "Appearance leaves data intact")
			first.free()
			second.free()
	_check(variants.size() == 4, "All four variants sampled")
	for scene in world.tree_scenes.values():
		var instance: Node3D = scene.instantiate()
		root.add_child(instance)
		var sprite := instance.get_node("Visual/Default/Sprite") as AnimatedSprite3D
		_check(sprite != null and sprite.is_playing(), "Animated tree autoplays")
		_check(sprite.sprite_frames.get_frame_count("idle") == 8 and sprite.sprite_frames.get_animation_loop("idle") and sprite.sprite_frames.get_animation_speed("idle") > 0.0, "Eight original frames with editable positive speed")
		_check(sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Nearest filtering")
		_check(instance.find_children("*", "MeshInstance3D", true, false).all(func(mesh): return mesh.name == "Shadow"), "No old tree geometry; optional editable shadows allowed")
		instance.free()
	_test_lifecycle(world)
	_test_saved_world(world)
	world.free()
	for failure in failures.slice(0, 20):
		push_error(failure)
	print("%s trees: %d checks; 64 seeds, four scenes, harvest/rain and saved world" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _test_lifecycle(world: Node3D) -> void:
	var state := State.create_initial("tree-lifecycle")
	var tree: Dictionary = state.resources.filter(func(n): return n.source == "tree" and n.biome == "meadow")[0]
	var unit := State.create_unit("test-lumberjack", "lumberjack", {"x": tree.position.x + 1.35, "y": tree.position.y})
	state.units = [unit]
	state.barbarians = []
	state.animals = []
	state.totem.position = {"x": tree.position.x + 5, "y": tree.position.y}
	unit.task = {"kind": "gather", "targetResourceId": tree.id, "destination": null, "cause": "test"}
	unit.actionProgressSeconds = 2.95
	_check(Work.gather_duration(state, tree) == 3.0, "Original harvest duration")
	world.setup(state)
	var path: String = world._views[tree.id].scene_file_path
	Work.update_unit(state, unit, 0.05, Move.create_frame(state, 0.05))
	_check(tree.amount == 0, "Harvest consumes tree")
	_check(state.drops.size() == tree.yieldAmount and state.drops.all(func(d): return d.type == "wood" and d.amount == 1), "Two or three separate wood drops")
	world.sync(state)
	_check(not world._views.has(tree.id), "Depleted visual removed")
	state.weather.clouds = [{"id": "test-cloud", "position": tree.position.duplicate(), "targetBiomeInstanceId": tree.biomeInstanceId, "phase": "approaching", "phaseElapsedSeconds": 0.0, "rainRemainingSeconds": 0.0}]
	var biome: Dictionary = state.biomes.filter(func(b): return b.instanceId == tree.biomeInstanceId)[0]
	state.weather.clouds[0].position = {"x": biome.region.x, "y": biome.region.y}
	Weather.update(state, 0.05)
	_check(tree.amount == tree.maxAmount, "Rain replenishes meadow wood")
	world.sync(state)
	_check(world._views.has(tree.id) and world._views[tree.id].scene_file_path == path, "Rain restores identical tree appearance")

func _test_saved_world(world: Node3D) -> void:
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/typescript_reference.json"))
	var old: Dictionary = reference.initialStates[0].duplicate(true)
	var directory := "user://tree-save-check-%d" % OS.get_process_id()
	var repository := Saves.new(directory)
	_check(repository.save_slot(1, old).ok, "Existing v17 world saves")
	var result := repository.read_slot(1)
	_check(result.status == "valid", "Existing v17 world loads")
	if result.status == "valid":
		var restored: Dictionary = result.save.gameState
		_check(restored.biomes == old.biomes and restored.resources == old.resources, "Saved map never regenerated")
		var before := JSON.stringify(restored)
		world.setup(restored)
		_check(before == JSON.stringify(restored), "Loaded world presentation does not mutate save")
	repository.delete_slot(1)
	DirAccess.remove_absolute(directory)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
