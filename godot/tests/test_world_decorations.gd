extends SceneTree
## Procedural invariants and sprite scene integration; no gameplay ticks.

const Catalog = preload("res://scripts/simulation/world_catalog.gd")
const State = preload("res://scripts/simulation/game_state.gd")
const World = preload("res://scenes/WorldView.tscn")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for index in 32:
		var seed_text := "sprite-decoration-%s" % index
		var blueprint := Catalog.create_blueprint(seed_text)
		var biomes: Array = blueprint.biomes
		var decorations: Array = blueprint.decorations
		_check(decorations == Catalog.create_decorations(seed_text, biomes,blueprint.resources,blueprint.terrain), "Repeatable generation")
		var water: Array = decorations.filter(func(entry): return entry.kind == "water-rock")
		_check(water.size() >= 24 and water.size() <= 48 and water.size() % 3 == 0, "Tripled coastal rock population")
		var occupied: Array[Vector2i] = []
		for rock in water:
			var cell := Catalog.Terrain.cell(rock.position)
			_check(not occupied.any(func(other): return cell.distance_squared_to(other) < 4.0),
				"Rock cells are unique and at least two cells apart")
			occupied.append(cell)
			for dx in range(-1, 2):
				for dy in range(-2, 3):
					_check(Catalog.Terrain.code(blueprint.terrain, cell + Vector2i(dx, dy)) == Catalog.Terrain.SEA,
						"Rock has water clearance")
		_check_water_groups(occupied)
		for biome in biomes:
			var entries: Array = decorations.filter(func(item): return item.biomeInstanceId == biome.instanceId)
			if biome.id not in ["clearing", "forest", "meadow"]:
				_check(entries.is_empty(), "No vegetation in rocky/ruins")
				continue
			for kind in ["bush","grass"]:
				var group: Array = entries.filter(func(entry): return entry.kind == kind)
				if group.is_empty(): continue
				_check(group.size() in ([2,3] if kind == "bush" else [3,4,5]),"Cluster size")
				for entry in group:
					_check(Catalog._distance(entry.position,group[0].position) <= 1.06,"Cluster stays together")
			var mushrooms := 0
			for entry in entries:
				_check(entry.kind in ["grass", "mushroom", "bush"], "Only current vegetation kinds")
				_check(not entry.has("flowerColor"), "No retired flower data")
				mushrooms += int(entry.kind == "mushroom")
				var point := Vector2(entry.position.x, entry.position.y)
				_check(Catalog.Footprint.contains(biome.region, point), "Vegetation inside biome tiles")
			_check(mushrooms <= 1 and entries.size() <= 9, "Sparse decoration")
	_test_views()
	for failure in failures.slice(0, 20):
		push_error(failure)
	print("%s decoration: %d checks, 32 seeds, scene integration; no gameplay ticks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

func _check_water_groups(cells: Array[Vector2i]) -> void:
	var remaining := cells.duplicate()
	var sizes := {}
	var solitary := 0
	while not remaining.is_empty():
		var group: Array[Vector2i] = [remaining.pop_back()]
		var index := 0
		while index < group.size():
			for candidate in range(remaining.size() - 1, -1, -1):
				if group[index].distance_squared_to(remaining[candidate]) <= 16.0:
					group.append(remaining[candidate])
					remaining.remove_at(candidate)
			index += 1
		_check(group.size() <= 5, "Coastal groups do not merge")
		sizes[group.size()] = true
		solitary += int(group.size() == 1)
	for size in range(2, 6):
		_check(sizes.has(size), "Coastal layout includes groups of size %d" % size)
	_check(solitary <= 2, "Most rocks belong to discernible groups")

func _test_views() -> void:
	var state := State.create_initial()
	var original := JSON.stringify(state)
	var world := World.instantiate()
	root.add_child(world)
	world.setup(state)
	var first := _appearance(world)
	_check(first.size() <= state.decorations.size() and not first.is_empty(), "Valid decoration subset after visual clearance")
	var textures := {}
	for item in first:
		textures[item.texture] = true
	_check(textures.size() >= 5, "Vegetation variants represented")
	var rocks := world.get_children().filter(func(child): return child is AnimatedSprite3D)
	_check(rocks.size() == state.decorations.filter(func(item): return item.kind == "water-rock").size(),"All saved water rocks have a view")
	for rock: AnimatedSprite3D in rocks:
		_check(rock.is_playing(), "Coastal rocks animate automatically")
	_check(world.water_rock_scenes.size() == 8, "Eight coastal rock scenes")
	for index in world.water_rock_scenes.size():
		var rock := world.water_rock_scenes[index].instantiate() as AnimatedSprite3D
		var frames := rock.sprite_frames
		var count := 8 if index < 4 else 16
		var cell_size := 128 if index < 4 else 64
		_check(frames.get_frame_count("default") == count and frames.get_animation_loop("default")
			and frames.get_animation_speed("default") == 10.0, "Rock uses the expected atlas timing")
		_check(rock.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Rock uses Nearest")
		for frame in count:
			var atlas := frames.get_frame_texture("default", frame) as AtlasTexture
			_check(atlas.region == Rect2(frame * cell_size, 0, cell_size, cell_size), "Rock atlas frame is correctly sliced")
		rock.free()
	world.setup(state)
	_check(first == _appearance(world), "Stable texture, size and flip on rebuild")
	_check(original == JSON.stringify(state), "Presentation does not mutate state")
	for scene in world.decoration_scenes.values():
		var instance: Node3D = scene.instantiate()
		var sprite := instance.get_node("Visual/Default/Sprite") as SpriteBase3D
		_check(instance.find_children("*", "MeshInstance3D", true, false).is_empty(), "No temporary decoration geometry")
		_check(instance.find_children("*", "CollisionObject3D", true, false).is_empty(), "Decorative bushes remain non-interactive")
		_check(_texture(sprite) != null and sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Sprite texture uses nearest filtering")
		if sprite is AnimatedSprite3D:
			_check(sprite.sprite_frames.get_frame_count("idle") == 8 and sprite.sprite_frames.get_animation_speed("idle") > 0.0 and sprite.sprite_frames.get_animation_loop("idle"), "Eight-frame loop with editable positive speed")
		else:
			_check(sprite is Sprite3D, "Other vegetation stays static")
		instance.free()
	for biome in ["clearing", "meadow", "forest"]:
		var sampled := {}
		for index in 48:
			var decoration := {"kind": "bush", "id": "bush-check-%d" % index, "biome": biome, "position": {"x": 10, "y": 10}, "scale": 1.4}
			world._create_decoration(decoration, "bush-sample")
			var view := world.get_child(world.get_child_count() - 1)
			var sprite := view.get_node("Visual/Default/Sprite") as SpriteBase3D
			var file: String = (_texture(sprite) as AtlasTexture).atlas.resource_path.get_file()
			sampled[file] = true
			_check(file in (["Bush small.png", "Bushe3.png", "Bushe4.png"] if biome == "forest" else ["Bush small.png", "Bushe1.png", "Bushe2.png"]), "Correct bush pair by biome")
			if sprite is AnimatedSprite3D:
				_check(sprite.is_playing(), "Animated bushes autoplay")
			else:
				_check(file == "Bush small.png", "Small bush stays static")
			view.free()
		_check(sampled.size() == 3, "Both animated choices and small bush represented")
	world.setup(JSON.parse_string(original))
	_check(first == _appearance(world), "Stable appearance after save JSON")
	var legacy: Dictionary = JSON.parse_string(original)
	var removed := 0
	for index in range(legacy.decorations.size() - 1, -1, -1):
		if removed == rocks.size() * 2 / 3:
			break
		if legacy.decorations[index].kind == "water-rock":
			legacy.decorations.remove_at(index)
			removed += 1
	world.setup(legacy)
	var legacy_rocks := world.get_children().filter(func(child): return child is AnimatedSprite3D)
	_check(legacy_rocks.size() == rocks.size() / 3, "Loading a sparse map preserves its saved rock count")
	world.free()

func _appearance(world: Node3D) -> Array:
	var result: Array = []
	for child in world.get_children():
		var sprite := child.get_node_or_null("Visual/Default/Sprite") as SpriteBase3D
		var texture := _texture(sprite)
		if texture is AtlasTexture and texture.atlas.resource_path.begins_with("res://assets/environment/"):
			result.append({"texture": texture.atlas.resource_path, "flip": sprite.flip_h, "scale": child.scale, "position": child.position})
	return result

func _texture(sprite: SpriteBase3D) -> Texture2D:
	if sprite is Sprite3D:
		return sprite.texture
	if sprite is AnimatedSprite3D:
		return sprite.sprite_frames.get_frame_texture("idle", 0)
	return null

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
