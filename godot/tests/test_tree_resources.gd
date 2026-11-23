extends SceneTree
## World guarantees, appearance isolation, and actual harvest/rain lifecycle.
const Catalog = preload("res://scripts/simulation/world_catalog.gd")
const State = preload("res://scripts/simulation/game_state.gd")
const World = preload("res://scenes/WorldView.tscn")
const Work = preload("res://scripts/simulation/work_system.gd")
const Move = preload("res://scripts/simulation/minion_movement.gd")
const Weather = preload("res://scripts/simulation/weather_system.gd")
const Economy = preload("res://scripts/simulation/economy.gd")
const Conflict = preload("res://scripts/simulation/conflict_system.gd")
const Saves = preload("res://scripts/persistence/save_repository.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var fallback := Catalog.Reserve.blueprint
	_check(Catalog._usable_resources(fallback,fallback.resources) and fallback.barbarians.size() == 5 and fallback.animals.size() == 6,"Playable populated reserve")
	var layouts := {}
	for index in 64:
		var seed_text := "relieve-%03d" % index
		var blueprint := Catalog.create_blueprint(seed_text)
		_check_archipelago(blueprint,seed_text)
		var layers: Array[Dictionary] = [{},{},{}]
		layouts[hash(blueprint.terrain)] = true
		_check(blueprint == Catalog.create_blueprint(seed_text), "Repeatable blueprint")
		_check(blueprint.biomes.filter(func(b): return not b.isDecorativeOnly).size() >= 6, "Functional biomes on terraces")
		_check(blueprint.biomes.filter(func(b): return b.id == "forest").size() >= 3, "At least three forests")
		var meadows: Array = blueprint.biomes.filter(func(b): return b.id == "meadow")
		var animals := Catalog.create_rabbits(seed_text, blueprint.biomes)
		var starter: Dictionary = meadows.filter(func(b): return b.get("startingMeadow",false))[0]
		_check(animals.filter(func(a): return a.homeBiomeId == starter.instanceId).size() == 2,"Two starting sheep")
		for source in ["berry-bush","tree"]:
			_check(blueprint.resources.filter(func(n): return n.biomeInstanceId == starter.instanceId and n.source == source).size() == 1,"Exactly one starting "+source)
			_check(blueprint.resources.any(func(n): return n.biomeInstanceId == starter.instanceId and n.source == source and Vector2(n.position.x,n.position.y).distance_to(Vector2(80,80)) <= 10),"Starting "+source)
		for animal_index in animals.size():
			var animal: Dictionary = animals[animal_index]
			var region: Dictionary = meadows.filter(func(b): return b.instanceId == animal.homeBiomeId)[0].region
			for point: Dictionary in [animal.spawnPosition, animal.patrolTarget]:
				_check(Catalog.Footprint.contains(region, Vector2(point.x, point.y)), "Sheep inside meadow")
		var ids := {}
		for node in blueprint.resources:
			_check(not ids.has(node.id), "Unique resource IDs")
			ids[node.id] = true
			var biome: Dictionary = blueprint.biomes.filter(func(b): return b.instanceId == node.biomeInstanceId)[0]
			var point := Vector2(node.position.x, node.position.y)
			_check(Catalog.Footprint.contains(biome.region, point), "Resources inside biome tiles")
			if node.type in ["spark","stone"]:
				_check(biome.level >= 2 or biome.id in ["mountain","ruins"],"Low mineral in its native biome")
			if not biome.isDecorativeOnly and not biome.get("startingMeadow",false):
				_check(point.distance_to(Vector2(80, 80)) >= 12.0, "Starting resource exclusion")
		for biome in blueprint.biomes:
			var rule: Array = {"forest":["wood",5,8],"meadow":["wood",2,4],"rocky":["stone",4,6]}.get(biome.id,[])
			if biome.get("startingMeadow",false):
				rule = ["wood",1,1]
			if not rule.is_empty():
				var nodes: Array = blueprint.resources.filter(func(n): return n.biomeInstanceId == biome.instanceId and n.type == rule[0])
				_check(nodes.size() >= rule[1] and nodes.size() <= rule[2],"Resource density by biome")
			if biome.level > 1:
				var rect := Rect2i()
				for tile in biome.region.cells + biome.region.get("covered",[]):
					var location := Vector2i(tile.x,tile.y)
					rect = Rect2i(location,Vector2i.ZERO) if rect == Rect2i() else rect.expand(location)
				var size := rect.size + Vector2i.ONE
				_check(size.x >= 4 and size.y >= 4 and size.x <= 17 and size.y <= 19,"Playable terrace within tile bounds")
		var occupied := {}
		for biome in blueprint.biomes:
			_check_connected(biome.region)
			if biome.id == "meadow":
				var nodes: Array = blueprint.resources.filter(func(n): return n.biomeInstanceId == biome.instanceId)
				_check(nodes.any(func(n): return n.source == "tree"), "Meadow has wood")
				_check(nodes.any(func(n): return n.source == "berry-bush"), "Meadow retains berries")
			var origin := Catalog.Terrain.cell(biome.region)
			for entry in biome.region.cells + biome.region.get("covered",[]):
				layers[int(biome.level)-1][origin+Vector2i(entry.x,entry.y)] = biome.id
			for entry in biome.region.cells:
				var c := origin + Vector2i(entry.x,entry.y)
				_check(not occupied.has(c),"Single biome per world cell")
				occupied[c] = true
			if biome.id == "rocky":
				_check(biome.level >= 2,"Rocky biome on plateau")

		for layer in [1,2]:
			for c: Vector2i in layers[layer]:
				for direction in Catalog.Terrain.DIRS:
					var n: Vector2i = c + direction
					if layers[layer].has(n): continue
					if layer == 2: _check(layers[1].has(n),"Visible middle terrace")
					if layers[layer-1].has(n):
						_check(Catalog.Islands.contrasts(layers[layer][c],layers[layer-1][n]),"Contrasting adjoining terraces")

	_check(layouts.size() == 64, "Each sampled seed has its own geography")
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
	_test_weather_cadence()
	_test_lifecycle(world)
	_test_resource_drops()
	_test_barbarian_loot()
	_test_saved_world(world)
	world.free()
	for failure in failures.slice(0, 20):
		push_error(failure)
	print("%s trees: %d checks; 64 seeds, four scenes, harvest/rain and saved world" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _check_archipelago(world: Dictionary, seed_text: String) -> void:
	var terrain: Array = world.terrain
	var graph := Catalog.Terrain.graph(terrain)
	var start := Catalog.Islands.START
	var home := start.y*Catalog.Terrain.SIZE+start.x
	var counts := [0,0,0]
	var area := [0,0,0]
	for biome in world.biomes:
		var level: int = biome.level
		counts[level-1] += 1
		area[level-1] += biome.region.cells.size()
		if level == 1: continue
		var c := Catalog.Terrain.cell(biome.region)
		var entrances := {}
		for local in biome.region.cells:
			var landing := c + Vector2i(local.x,local.y)
			for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT]:
				var stair := landing + direction
				var tile := Catalog.Terrain.code(terrain,stair)
				if Catalog.Terrain.ramp(tile) and Catalog.Terrain.level(tile) == level-1 and Catalog.Terrain.edge(terrain,landing,stair) and Catalog.Terrain.edge(terrain,stair,stair+direction):
					entrances[stair] = true
		var lanes := entrances.keys()
		_check(lanes.size() == (5 if level == 2 else 2) and lanes.all(func(lane): return lane.x == lanes[0].x),seed_text+" usable stair lanes to "+biome.instanceId)
		var route := graph.get_id_path(home,c.y*Catalog.Terrain.SIZE+c.x)
		var stairs := {}
		for id in route:
			var tile := Catalog.Terrain.code(terrain,Vector2i(id%Catalog.Terrain.SIZE,floori(float(id)/Catalog.Terrain.SIZE)))
			if Catalog.Terrain.ramp(tile): stairs[Catalog.Terrain.level(tile)] = true
		_check(stairs.has(1) and (level == 2 or stairs.has(2)),seed_text+" stair route to "+biome.instanceId)
	for x in range(-8,9):
		for y in range(-8,9):
			_check(Catalog.Terrain.code(terrain,start+Vector2i(x,y)) == Catalog.Terrain.LOW,seed_text+" flat start")
	_check(counts[1] in [7,8] and counts[2] in [3,4],seed_text+" terrace counts")
	_check(area[0] > area[1]+area[2],seed_text+" majority low ground")

func _test_weather_cadence() -> void:
	var state := State.create_initial("weather-cadence")
	for resource in state.resources:
		resource.amount = 0
	Weather.update(state, 0.05)
	var first: Dictionary = state.weather.clouds[0]
	var initial_position: Dictionary = first.position.duplicate()
	Weather.update(state, 30.0)
	_check(first.phase == "passing" and first.position != initial_position, "Dry clouds drift from the start")
	_check(state.weather.clouds.size() == 2, "A new cloud enters after 30 seconds")
	_check(state.resources.all(func(resource): return resource.amount == 0), "Dry clouds leave resources depleted")
	for second in 55:
		Weather.update(state, 1.0)
	_check(not state.weather.clouds.any(func(cloud): return cloud.phase in ["approaching","raining"]), "Dry weather until first rain cloud at 90 seconds")
	for second in 32:
		Weather.update(state, 1.0)
	_check(state.weather.clouds.any(func(cloud): return cloud.phase == "raining"), "First rain arrives after its approach")
	_check(state.resources.any(func(resource): return resource.amount > 0), "Rain replenishes resources")
	for second in 64:
		Weather.update(state, 1.0)
	var next_rain: Array = state.weather.clouds.filter(func(cloud): return cloud.phase == "approaching")
	_check(next_rain.size() == 1 and next_rain[0].id == "weather-cloud-007", "Rain clouds enter 90 seconds apart")

	var enemy: Dictionary = state.barbarians[0]
	Conflict._defeat_barbarian(state,enemy)
	_check(enemy.respawnRemainingSeconds == 180.0, "Defeated barbarian waits 180 seconds")
	Conflict._update_respawns_and_fauna(state,179.0)
	_check(not enemy.isAlive, "Barbarian stays defeated before timeout")
	Conflict._update_respawns_and_fauna(state,1.0)
	_check(enemy.isAlive, "Barbarian respawns at timeout")

	var sheep: Dictionary = state.animals[0]
	var hunter: Dictionary = state.units[0]
	hunter.role = "hunter"
	Conflict._attack(state,hunter,sheep,{"damage":sheep.health,"cooldownSeconds":1.0},"animal")
	var shot: Dictionary = state.hunterShots[0]
	state.tick = shot.releaseTick
	Conflict.update_hunter_shots(state)
	state.tick = shot.impactTick
	Conflict.update_hunter_shots(state)
	_check(state.drops.size() == 1 and state.drops.all(func(d): return d.type == "food" and d.amount == 1 and d.sourceNodeId == sheep.id), "One food drop per hunted sheep")
	_check(sheep.respawnRemainingSeconds == 90.0 and not sheep.isAlive, "Hunted sheep waits 90 seconds")
	Conflict._update_respawns_and_fauna(state,89.0)
	_check(not sheep.isAlive, "Sheep stays defeated before timeout")
	Conflict._update_respawns_and_fauna(state,1.0)
	_check(sheep.isAlive and sheep.position == sheep.spawnPosition, "Sheep respawns at home at timeout")

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
	_check(state.drops.size() == 1 and state.drops.all(func(d): return d.type == "wood" and d.amount == 1), "One wood drop per tree")
	world.sync(state)
	_check(not world._views.has(tree.id), "Depleted visual removed")
	state.weather.clouds = [{"id": "test-cloud", "position": tree.position.duplicate(), "targetBiomeInstanceId": tree.biomeInstanceId, "phase": "approaching", "phaseElapsedSeconds": 0.0, "rainRemainingSeconds": 0.0}]
	var biome: Dictionary = state.biomes.filter(func(b): return b.instanceId == tree.biomeInstanceId)[0]
	state.weather.clouds[0].position = {"x": biome.region.x, "y": biome.region.y}
	Weather.update(state, 0.05)
	_check(tree.amount == tree.maxAmount, "Rain replenishes meadow wood")
	world.sync(state)
	_check(world._views.has(tree.id) and world._views[tree.id].scene_file_path == path, "Rain restores identical tree appearance")

func _harvest_at_node(state: Dictionary, node: Dictionary, role: String, bonus_tool: String = "") -> void:
	state.terrain = []
	var position := {"x": node.position.x + node.interactionRadius, "y": node.position.y}
	var unit := State.create_unit("test-harvester", role, position)
	state.units = [unit]
	unit.task = {"kind": "gather", "targetResourceId": node.id, "destination": position, "cause": "test"}
	unit.actionProgressSeconds = Work.gather_duration(state, node)
	if not bonus_tool.is_empty():
		var found_bonus := false
		for tick in range(128):
			if Economy.rolls_bonus(state.seed, tick, unit.id, node.id, bonus_tool, state.toolLevels[bonus_tool]):
				state.tick = tick
				found_bonus = true
				break
		_check(found_bonus, "Deterministic bonus roll for " + bonus_tool)
	Work.update_unit(state, unit, 0.05, Move.create_frame(state, 0.05))

func _test_resource_drops() -> void:
	var initial := State.create_initial("resource-drops")
	for source in ["twigs", "berry-bush", "stone-vein", "ruin"]:
		var state := initial.duplicate(true)
		var node: Dictionary = state.resources.filter(func(candidate): return candidate.source == source)[0]
		var role: String = {"twigs": "gatherer", "berry-bush": "gatherer"}.get(source, "artisan")
		var inventory_before: Dictionary = state.inventory.amounts.duplicate()
		_harvest_at_node(state, node, role)
		_check(state.drops.size() == 1 and state.drops.all(func(d): return d.type == node.type and d.amount == 1 and d.sourceNodeId == node.id), "One base drop from " + source)
		if source == "berry-bush":
			_check(state.drops.any(func(d): return d.get("appearance") == "berries"), "Berry harvest selects the berry sprite variant")
		_check(state.inventory.amounts == inventory_before, "Harvest waits for physical pickup")
	for tool in ["axe", "hammer"]:
		var state := initial.duplicate(true)
		state.toolLevels[tool] = 10
		var source := "tree" if tool == "axe" else "stone-vein"
		var node: Dictionary = state.resources.filter(func(candidate): return candidate.source == source)[0]
		_harvest_at_node(state, node, "lumberjack" if tool == "axe" else "artisan", tool)
		_check(state.drops.size() == 2 and state.drops.all(func(d): return d.type == node.type and d.amount == 1), "One additional drop from " + tool)

func _test_barbarian_loot() -> void:
	var state := State.create_initial("barbarian-loot")
	var barbarian: Dictionary = state.barbarians[0]
	var expected := State.empty_amounts()
	var found_multiple_gold := false
	for cycle in range(128):
		var random := Conflict.Random.new("%s:barbarian-loot:%s:%s" % [state.seed, barbarian.id, cycle])
		expected.gold = random.next_int(1, 2)
		expected.food = random.next_int(0, 2)
		expected.wood = random.next_int(0, 1)
		if expected.gold == 2:
			barbarian.spawnCycle = cycle
			found_multiple_gold = true
			break
	_check(found_multiple_gold, "Deterministic barbarian loot with two gold")
	Conflict._defeat_barbarian(state, barbarian)
	var corpse: Dictionary = state.barbarianCorpses[0]
	_check(corpse.loot == expected, "Barbarian keeps its original loot table")
	var unit := State.create_unit("test-looter", "gatherer", {"x": corpse.position.x + 1.25, "y": corpse.position.y})
	state.terrain = []
	state.units = [unit]
	unit.task = {"kind": "loot-corpse", "targetEntityId": corpse.id, "cause": "test"}
	unit.actionProgressSeconds = 1.5
	Work.update_unit(state, unit, 0.05, Move.create_frame(state, 0.05))
	for resource_type in ["gold", "food", "wood"]:
		_check(state.drops.filter(func(d): return d.type == resource_type and d.amount == 1).size() == expected[resource_type], "Barbarian drops all " + resource_type)

func _test_saved_world(world: Node3D) -> void:
	var original := State.create_initial("saved-tile-world")
	Weather.update(original, 0.05)
	var expected: Dictionary = JSON.parse_string(JSON.stringify(original, "", false, true))
	var directory := "user://tree-save-check-%d" % OS.get_process_id()
	var repository := Saves.new(directory)
	_check(repository.save_slot(1, original).ok, "Tiled world saves")
	var result := repository.read_slot(1)
	_check(result.status == "valid", "Tiled world loads")
	if result.status == "valid":
		var restored: Dictionary = result.save.gameState
		_check(restored.terrain == expected.terrain and restored.biomes == expected.biomes and restored.resources == expected.resources and restored.decorations == expected.decorations, "Saved map never regenerated")
		_check(restored.weather == expected.weather, "Moving dry clouds and schedule survive save/load")
		var before := JSON.stringify(restored)
		world.setup(restored)
		_check(before == JSON.stringify(restored), "Loaded world presentation does not mutate save")
	# Version 4 worlds from before grouped decoration lack this optional field.
	original.decorations = original.decorations.filter(func(item): return item.kind != "water-rock")
	for item in original.decorations:
		item.erase("grouped")
	var old_tree: Dictionary = original.resources.filter(func(node): return node.source == "tree")[0]
	old_tree.yieldAmount = 3
	Work.drop_resource(original, old_tree.position, "test", old_tree.id, "wood", 2)
	_check(repository.save_slot(2,original).ok,"Save legacy-shaped world")
	var legacy := repository.read_slot(2)
	_check(legacy.status == "valid" and legacy.save.gameState.decorations == JSON.parse_string(JSON.stringify(original.decorations,"",false,true)),"Existing decorations load without regeneration")
	if legacy.status == "valid":
		var restored: Dictionary = legacy.save.gameState
		_check(restored.drops.size() == 2, "Legacy drops already on the ground are retained")
		var tree: Dictionary = restored.resources.filter(func(node): return node.id == old_tree.id)[0]
		_harvest_at_node(restored, tree, "lumberjack")
		_check(restored.drops.size() == 3 and restored.drops.back().amount == 1, "Loaded tree ignores its legacy yield")
	repository.delete_slot(2)
	repository.delete_slot(1)
	DirAccess.remove_absolute(directory)

func _check_connected(region: Dictionary) -> void:
	var remaining := {}
	for cell in region.cells:
		var coord := Vector2i(cell.x, cell.y)
		remaining[coord] = true
		var corner := (Vector2(coord.abs()) + Vector2.ONE * 0.5) * Catalog.Footprint.TILE_SIZE
		_check(corner.length() <= region.size / 2.0 + 0.01, "Tile within placement envelope")
	var pending: Array[Vector2i] = [Vector2i.ZERO]
	_check(remaining.erase(Vector2i.ZERO), "Biome includes its center")
	while not pending.is_empty():
		var coord: Vector2i = pending.pop_back()
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if remaining.erase(coord + direction):
				pending.append(coord + direction)
	_check(remaining.is_empty(), "All tiles connected by edges")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
