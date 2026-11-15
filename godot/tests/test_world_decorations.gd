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
		var biomes := Catalog.create_biomes(seed_text)
		var decorations := Catalog.create_decorations(seed_text, biomes)
		_check(decorations == Catalog.create_decorations(seed_text, biomes), "Repeatable generation")
		for biome in biomes:
			var entries: Array = decorations.filter(func(item): return item.biomeInstanceId == biome.instanceId)
			if biome.id not in ["clearing", "forest", "meadow"]:
				_check(entries.is_empty(), "No vegetation in rocky/ruins")
				continue
			var limits: Array = {"clearing": [12, 18], "forest": [16, 24], "meadow": [18, 26]}[biome.id]
			_check(entries.size() >= limits[0] and entries.size() <= limits[1], "Biome density including starting clearing")
			var mushrooms := 0
			for entry in entries:
				_check(entry.kind in ["grass", "mushroom", "bush"], "Only current vegetation kinds")
				_check(not entry.has("flowerColor"), "No retired flower data")
				mushrooms += int(entry.kind == "mushroom")
				var distance := Vector2(entry.position.x - biome.region.x, entry.position.y - biome.region.y).length()
				_check(distance <= biome.region.size / 2.0 - 1.2 + 0.01, "Vegetation stays inside biome margin")
			_check(mushrooms <= 2, "At most two mushrooms even at increased density")
	_test_views()
	for failure in failures.slice(0, 20):
		push_error(failure)
	print("%s decoration: %d checks, 32 seeds, scene integration; no gameplay ticks" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)

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
	_check(textures.size() == 10, "All ten supplied vegetation variants represented")
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
