extends SceneTree

const State = preload("res://scripts/simulation/game_state.gd")
const Work = preload("res://scripts/simulation/work_system.gd")
const Move = preload("res://scripts/simulation/minion_movement.gd")
const Terrain = preload("res://scripts/simulation/island_terrain.gd")
const TerrainView = preload("res://scripts/view/terrain_projection.gd")
const Saves = preload("res://scripts/persistence/save_repository.gd")
const World = preload("res://scenes/WorldView.tscn")

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := State.create_initial("drop-flight")
	_check_destinations(state.duplicate(true))
	_check_pickup(state.duplicate(true))
	_check_save_and_view(state)
	print("Drop flight: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func _check_destinations(state: Dictionary) -> void:
	var origin := Terrain.center(Vector2i(20, 20))
	# Choose a repeatable launch towards the boundary immediately to the east.
	for tick in range(128):
		state.tick = tick
		var random := Work.Random.new("%s:drop:%s:unit:tree:wood" % [state.seed, tick])
		if cos(random.next_float(0, TAU)) > 0.99:
			break
	state.terrain = []
	Work.drop_resource(state, origin, "unit", "tree", "wood", 1)
	var open_drop: Dictionary = state.drops.back()
	_check(_distance(origin, open_drop.position) > 2.99 and open_drop.position.x > origin.x + 2.9, "Launch travels three metres east in open space")
	Work.drop_resource(state, origin, "unit", "tree", "wood", 1)
	_check(open_drop.position == state.drops.back().position, "Identical launch inputs land in the same place")
	for barrier: String in [".", "2"]:
		var row := "1".repeat(22) + barrier.repeat(Terrain.SIZE - 22)
		state.terrain = []
		for index in range(Terrain.SIZE):
			state.terrain.append(row)
		Work.drop_resource(state, origin, "unit", "tree", "wood", 1)
		var drop: Dictionary = state.drops.back()
		_check(is_equal_approx(_distance(origin, drop.position), 1.5), "Shorter launch stays clear of boundary " + barrier)
		_check(Terrain.same_level(state.terrain, origin, drop.position) and Terrain.fits(state.terrain, drop.position, 0.32, true), "Landing remains on passable ground")

	var cliff_edge := Terrain.center(Vector2i(21, 20))
	Work.drop_resource(state, cliff_edge, "unit", "tree", "wood", 1)
	var blocked: Dictionary = state.drops.back()
	_check(blocked.position == cliff_edge and blocked.launchOrigin == cliff_edge, "A completely blocked throw bounces in place")

func _check_pickup(state: Dictionary) -> void:
	state.terrain = []
	Work.drop_resource(state, {"x": 80.0, "y": 80.0}, "unit", "tree", "wood", 1)
	var drop: Dictionary = state.drops[0]
	var unit := State.create_unit("collector", "gatherer", drop.position.duplicate())
	state.units = [unit]
	var inventory_before: int = state.inventory.amounts.wood
	var task := {"kind": "collect-drop", "targetResourceId": drop.id, "destination": drop.position.duplicate(), "cause": "test"}
	Work.set_task(unit, task.duplicate(true))
	state.tick = drop.launchTick + Work.DROP_SETTLE_TICKS - 1
	Work.update_unit(state, unit, 0.05, Move.create_frame(state, 0.05))
	_check(unit.task.kind == "collect-drop" and state.drops.size() == 1 and state.inventory.amounts.wood == inventory_before, "Collector waits through the final bounce")
	state.tick += 1
	Work.update_unit(state, unit, 0.05, Move.create_frame(state, 0.05))
	_check(state.drops.is_empty() and state.inventory.amounts.wood == inventory_before + 1, "Collector picks up the settled piece")
	Work.set_task(unit, task.duplicate(true))
	Work.update_unit(state, unit, 0.05, Move.create_frame(state, 0.05))
	_check(state.inventory.amounts.wood == inventory_before + 1, "A piece cannot be collected twice")

func _check_save_and_view(state: Dictionary) -> void:
	var berry: Dictionary = state.resources.filter(func(node): return node.source == "berry-bush")[0]
	Work.drop_resource(state, berry.position, "unit", berry.id, "food", 1, "berries")
	for resource_type: String in ["food", "gold", "wood", "stone", "spark"]:
		Work.drop_resource(state, berry.position, "unit", "test", resource_type, 1)
	var legacy_drop: Dictionary = state.drops[0].duplicate(true)
	legacy_drop.id = "legacy-berry"
	for key in ["appearance", "launchOrigin", "launchTick"]:
		legacy_drop.erase(key)
	state.drops.append(legacy_drop)
	state.tick += 5
	var directory := "user://drop-flight-test-%d" % OS.get_process_id()
	var repository := Saves.new(directory)
	_check(repository.save_slot(1, state).ok, "Save during flight")
	var result := repository.read_slot(1)
	_check(result.status == "valid", "Load a save with legacy and in-flight drops")
	if result.status == "valid":
		var restored: Dictionary = result.save.gameState
		var world := World.instantiate()
		root.add_child(world)
		world.setup(restored)
		var expected := ["B", "M", "G", "W", "R", "S", "B"]
		var wood_view: Node3D = world._views[restored.drops[3].id]
		var wood_sprite: Sprite3D = wood_view.get_node("Visual/Default/Sprite")
		var wood_shadow: Node3D = wood_view.get_node("Shadow")
		for index in restored.drops.size():
			var drop: Dictionary = restored.drops[index]
			var view: Node3D = world._views[drop.id]
			var sprite := view.get_node("Visual/Default/Sprite") as Sprite3D
			var texture := sprite.texture as AtlasTexture
			_check(texture.atlas.resource_path.ends_with(expected[index] + "_Idle.png"), "Sprite matches " + expected[index])
			_check(is_zero_approx(sprite.get_item_rect().position.y), "Sprite bottom is at its ground pivot: " + expected[index])
			_check(sprite.transform.is_equal_approx(wood_sprite.transform), "Sprite placement matches wood: " + expected[index])
			_check(view.get_node("Shadow").transform.is_equal_approx(wood_shadow.transform), "Shadow placement and scale match wood: " + expected[index])
		var launched: Dictionary = restored.drops[0]
		var animated: Node3D = world._views[launched.id]
		var visual := animated.get_node("Visual") as Node3D
		var legacy: Node3D = world._views[legacy_drop.id]
		_check(legacy.position.is_equal_approx(TerrainView.world(legacy_drop.position, restored.terrain)), "Legacy drop loads settled")
		var saved_phase := 5.0 / Work.DROP_FLIGHT_TICKS
		var saved_height: float = 4.0 * animated.launch_height * saved_phase * (1.0 - saved_phase)
		_check(is_equal_approx(visual.position.y, animated.visual_offset.y + saved_height), "New drop resumes at the saved flight phase")
		for elapsed: float in [9.0, 13.0]:
			animated.present_drop(launched, launched.launchTick + elapsed, restored.terrain)
			_check(visual.position.is_equal_approx(animated.visual_offset), "Ground contact at tick %s" % elapsed)
		var pickup_sprite := animated.get_node("Visual/Default/Sprite") as Sprite3D
		var idle_start: int = launched.launchTick + Work.DROP_SETTLE_TICKS
		for elapsed: float in [0.0, 2.0, 10.0, 16.0, 26.0]:
			animated.present_drop(launched, launched.launchTick + elapsed, restored.terrain)
			_check(pickup_sprite.scale.is_equal_approx(Vector3.ONE) and not pickup_sprite.flip_h, "Drop retains its sprite orientation and proportions")
		_check(animated.position.is_equal_approx(TerrainView.world(launched.position, restored.terrain)), "Visual lands at pickup position")
		restored.tick = idle_start
		_check(repository.save_slot(1, restored).ok, "Save after settling")
		var settled := repository.read_slot(1)
		_check(settled.status == "valid", "Load a save with settled drops")
		if settled.status == "valid":
			world.setup(settled.save.gameState)
			animated = world._views[launched.id]
			_check(animated.get_node("Visual").position.is_equal_approx(animated.visual_offset + Vector3.UP * animated.settled_lift), "Settled drop stays settled after load")
		world.free()
	repository.delete_slot(1)
	DirAccess.remove_absolute(directory)

func _distance(a: Dictionary, b: Dictionary) -> float:
	return Vector2(a.x, a.y).distance_to(Vector2(b.x, b.y))

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
