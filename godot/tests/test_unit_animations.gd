extends SceneTree
## Asset import, scene wiring and playback through the normal WorldView sync.
const Conflict = preload("res://scripts/simulation/conflict_system.gd")
const Saves = preload("res://scripts/persistence/save_repository.gd")
const Session = preload("res://scripts/simulation/game_session.gd")
const State = preload("res://scripts/simulation/game_state.gd")
const TerrainView = preload("res://scripts/view/terrain_projection.gd")
const World = preload("res://scenes/WorldView.tscn")
const Survival = preload("res://scripts/simulation/survival_system.gd")
const ACTORS := "res://scenes/actors/"
const RED := "res://assets/characters/red_units/"
const BLACK := "res://assets/enemies/black_units/"
const BUILDINGS := "res://assets/buildings/"
const PLAYABLE := {
	"gatherer": "Gatherer", "hunter": "Hunter", "guardian": "Guardian",
	"lumberjack": "Lumberjack", "artisan": "Artisan", "mage": "Mage",
}
const BLACK_ROLES := ["guardian", "recolector", "picaro", "mago", "cazador",
	"lenador", "artesana", "minero", "lancero"]

var _checks := 0
var _failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var textures := _check_assets(RED, 192) + _check_assets(BLACK, 192)
	textures += _check_assets(BUILDINGS, 0)
	_check(textures == 87, "All 87 textures are present and imported")
	for name: String in PLAYABLE.values():
		_check_actor(ACTORS + name + ".tscn")
	for role: String in ["picaro", "minero"]:
		_check_actor(ACTORS + "red_units/" + role + ".tscn")
	for role: String in BLACK_ROLES:
		_check_actor(ACTORS + "black_units/" + role + ".tscn")
	var buildings := DirAccess.get_files_at("res://scenes/world/black_buildings")
	var building_count := 0
	for filename in buildings:
		if filename.get_extension() != "tscn":
			continue
		var scene := load("res://scenes/world/black_buildings/" + filename) as PackedScene
		var sprite := scene.instantiate() as Sprite3D
		_check(sprite.texture != null and sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST,
			filename + " has a Nearest texture")
		sprite.free()
		building_count += 1
	_check(building_count == 8, "All eight enemy buildings have scenes")
	await _check_playback()
	_check_hunter_resolution()
	_check_facing()
	_check_sheep_grazing()
	print("%s unit animations: %d checks" % ["PASS" if _failures == 0 else "FAIL", _checks])
	quit(0 if _failures == 0 else 1)

func _check_assets(directory: String, cell_size: int) -> int:
	var texture_count := 0
	for folder in DirAccess.get_directories_at(directory):
		texture_count += _check_assets(directory.path_join(folder), 320 if folder == "lancero" else cell_size)
	for filename in DirAccess.get_files_at(directory):
		if filename.get_extension() == "import" and filename.get_basename().get_extension() == "png":
			var path := directory.path_join(filename)
			var config := ConfigFile.new()
			_check(config.load(path) == OK, path + " loads")
			_check(config.get_value("params", "compress/mode", -1) == 0
				and config.get_value("params", "mipmaps/generate", true) == false
				and config.get_value("params", "detect_3d/compress_to", -1) == 0,
				path + " uses Lossless, no mipmaps and no 3D override")
			var source := directory.path_join(filename.get_basename())
			_check(config.get_value("deps", "source_file", "") == source and ResourceLoader.exists(source),
				path + " resolves the renamed texture")
			texture_count += 1
		elif filename.get_extension() == "tres":
			var frames := load(directory.path_join(filename)) as SpriteFrames
			for animation in frames.get_animation_names():
				var label := "%s/%s" % [filename, animation]
				_check(is_equal_approx(frames.get_animation_speed(animation), 10.0), label + " plays at 10 FPS")
				var count := frames.get_frame_count(animation)
				var first := frames.get_frame_texture(animation, 0) as AtlasTexture
				_check(first.atlas.get_width() == count * cell_size and first.atlas.get_height() == cell_size,
					label + " covers the full sheet")
				for index in count:
					var frame := frames.get_frame_texture(animation, index) as AtlasTexture
					_check(frame.atlas == first.atlas and frame.filter_clip
						and frame.region == Rect2(index * cell_size, 0, cell_size, cell_size)
						and frames.get_frame_duration(animation, index) == 1.0, label + " preserves atlas frame order")
	return texture_count

func _check_actor(path: String) -> void:
	var scene := load(path) as PackedScene
	var actor := scene.instantiate() as Node3D
	var sprite := actor.get_node("Body/Sprite") as AnimatedSprite3D
	_check(sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, path + " uses Nearest")
	for clip in [&"idle", &"move"]:
		_check(sprite.sprite_frames.get_frame_count(clip) > 1 and sprite.sprite_frames.get_animation_loop(clip),
			path + " has animated locomotion")
	var hit: Variant = actor.get_node("Selection/Shape")
	_check(hit is CollisionShape3D and hit.shape is BoxShape3D, path + " retains a selection shape")
	actor.free()

func _check_playback() -> void:
	var world := World.instantiate()
	root.add_child(world)
	var state := State.create_initial("unit-animation-test")
	world.setup(state)
	var actor: Dictionary = state.units[0]
	var id: String = actor.id
	for role: String in PLAYABLE:
		actor.role = role
		world.sync(state)
		var sprite: AnimatedSprite3D = world._views[id].get_node("Body/Sprite")
		var expected: String = ACTORS + PLAYABLE[role] + ".tscn"
		_check(world._views[id].scene_file_path == expected and sprite.animation == &"idle",
			"World swaps to %s when the unit's role changes" % role)
	actor.navigation = {"velocity": {"x": 1.0, "y": 0.0}}
	actor.state = "idle"
	var previous := {id: {"x": actor.position.x - 0.1, "y": actor.position.y}}
	world.sync(state, previous)
	var mage: AnimatedSprite3D = world._views[id].get_node("Body/Sprite")
	_check(mage.animation == &"move", "Movement selects the run animation")
	await create_timer(0.15).timeout
	_check(mage.frame > 0, "The run advances on repeated presentation")
	world.sync(state, {id: actor.position.duplicate()})
	_check(mage.animation == &"idle", "A stationary unit returns to idle despite retained navigation velocity")
	await create_timer(0.15).timeout
	_check(mage.frame > 0, "Idle playback advances after the unit stops")
	for role: String in ["lumberjack", "guardian", "mage"]:
		actor.role = role
		state.effects.clear()
		Survival.add_effect(state, "attack-lunge", id, actor.position, 0.22)
		world.sync(state)
		var sprite: AnimatedSprite3D = world._views[id].get_node("Body/Sprite")
		_check(sprite.animation == &"attack" and not sprite.sprite_frames.get_animation_loop(&"attack"),
			role + " starts a one-shot attack")
		sprite.set_frame_and_progress(1, 0.0)
		world.sync(state)
		_check(sprite.frame == 1, role + " does not restart the same effect")
		await create_timer(float(sprite.sprite_frames.get_frame_count(&"attack")) / 10.0 + 0.1).timeout
		world.sync(state, previous)
		_check(sprite.animation == &"move", role + " resumes movement after attacking")
		state.effects.clear()
		Survival.add_effect(state, "attack-lunge", id, actor.position, 0.22)
		world.sync(state)
		_check(sprite.animation == &"attack" and sprite.frame == 0, role + " plays the next attack event")
	state.effects.clear()
	for role: String in ["lumberjack", "artisan", "gatherer"]:
		actor.role = role
		actor.state = "gathering"
		actor.navigation.velocity = {"x": 0.0, "y": 0.0}
		world.sync(state)
		var sprite: AnimatedSprite3D = world._views[id].get_node("Body/Sprite")
		_check(sprite.animation == (&"idle" if role == "gatherer" else &"work"), role + " selects work or its idle fallback")
		await create_timer(0.15).timeout
		_check(sprite.frame > 0 and sprite.sprite_frames.get_animation_loop(sprite.animation),
			role + " advances through the looping work or idle clip")
	actor.role = "hunter"
	actor.state = "idle"
	var target: Dictionary = state.animals[0]
	var initial_health: float = target.health
	Conflict._attack(state, actor, target, {"damage": 1.0, "cooldownSeconds": 1.3}, "animal")
	world.sync(state)
	var hunter: AnimatedSprite3D = world._views[id].get_node("Body/Sprite")
	var shot: Dictionary = state.hunterShots[0]
	state.tick = shot.releaseTick - 1
	Conflict.update_hunter_shots(state)
	world.sync(state, {}, 0.99)
	_check(hunter.frame == 4 and not world._views.has(shot.id), "No arrow before the sixth draw frame")
	var spawn := hunter.get_node("ArrowSpawn") as Marker3D
	spawn.position.x += 0.1
	spawn.rotation.z = deg_to_rad(40.0)
	state.tick = shot.releaseTick
	Conflict.update_hunter_shots(state)
	world.sync(state, {}, 0.0)
	_check(hunter.frame == 5 and world._views.has(shot.id), "The arrow appears on the sixth frame")
	var arrow: Sprite3D = world._views[shot.id]
	_check(arrow.texture.resource_path.ends_with("/cazador_flecha.png"), "Flight uses the hunter arrow sprite")
	var launch_position := arrow.position
	var ground := TerrainView.world(shot.origin, state.terrain)
	var aim := TerrainView.world(shot.aim, state.terrain)
	var expected := spawn.position
	expected.x *= -1.0 if aim.x < ground.x else 1.0
	expected += ground + hunter.global_position - (world._views[id] as Node3D).global_position
	_check(launch_position.is_equal_approx(expected), "The arrow launches from the editable bow marker")
	var expected_angle := PI - spawn.rotation.z if aim.x < ground.x else spawn.rotation.z
	_check(arrow.global_basis.x.is_equal_approx(Vector3(cos(expected_angle), sin(expected_angle), 0)),
		"The arrow starts at the editable bow angle, mirrored when aiming left")
	state.phase = "paused"
	world.sync(state, {}, 0.9)
	_check(arrow.position == launch_position and hunter.frame == 5, "Pausing holds the flight and the draw frame")
	state.phase = "playing"
	state.tick = shot.impactTick - 1
	Conflict.update_hunter_shots(state)
	world.sync(state, {}, 0.9)
	_check(target.health == initial_health and world._views.has(shot.id), "Health stays unchanged throughout flight")
	state.tick = shot.impactTick
	Conflict.update_hunter_shots(state)
	world.sync(state)
	var impact: Dictionary = state.effects.back()
	_check(not world._views.has(shot.id) and target.health == maxf(initial_health - 1.0, 0.0)
		and world._views.has(impact.id), "The arrow disappears, health changes and a hit cue appears on the same tick")
	world.free()

func _check_hunter_resolution() -> void:
	for scenario: String in ["hit", "miss", "lethal", "carry", "death", "transform", "remove", "respawn", "save"]:
		var state := State.create_initial("unit-animation-test")
		var hunter: Dictionary = state.units[0]
		hunter.role = "hunter"
		var enemy: Dictionary = state.barbarians[0]
		enemy.health = 1.0 if scenario == "lethal" else 3.0
		var initial_health: float = enemy.health
		Conflict._attack(state, hunter, enemy, {"damage": 1.0, "cooldownSeconds": 1.3}, "barbarian")
		var shot: Dictionary = state.hunterShots[0]
		if scenario in ["carry", "death", "transform"]:
			if scenario == "carry":
				hunter.isCarried = true
			elif scenario == "death":
				hunter.health = 0
			else:
				hunter.role = "guardian"
			state.tick += 1
			Conflict.update_hunter_shots(state)
			_check(not state.has("hunterShots") and enemy.health == initial_health, scenario + " cancels the draw")
			continue
		state.tick = shot.releaseTick
		Conflict.update_hunter_shots(state)
		if scenario == "miss":
			enemy.position.x += 0.48
		elif scenario == "hit":
			enemy.position.x += 0.46
		elif scenario == "remove":
			state.units.erase(hunter)
		elif scenario == "respawn":
			enemy.spawnCycle += 1
		elif scenario == "save":
			var saves := Saves.new("user://hunter-shot-test-%d" % Time.get_ticks_usec())
			var written := saves.save_slot(1, state)
			var loaded := saves.read_slot(1)
			saves.delete_slot(1)
			_check(written.ok and loaded.status == "valid", "A shot in flight survives a save round trip")
			if loaded.status != "valid":
				continue
			state = loaded.save.gameState
			enemy = state.barbarians[0]
		state.tick = shot.impactTick
		Conflict.update_hunter_shots(state)
		Conflict.update_hunter_shots(state)
		var expected_health := initial_health if scenario in ["miss", "respawn"] else initial_health - 1.0
		var expected_effect := "hunter-miss" if scenario in ["miss", "respawn"] else "hunter-impact"
		var markers: Array = state.effects.filter(func(effect): return effect.kind == expected_effect)
		_check(enemy.health == expected_health and markers.size() == 1, scenario + " resolves once with the correct health and cue")
		if scenario == "lethal":
			_check(not enemy.isAlive and state.barbarianCorpses.size() == 1, "A lethal arrow creates loot at impact")
		state.tick += 1
		Conflict.update_hunter_shots(state)
		_check(not state.has("hunterShots"), "Resolved shots expire after the attack animation")

func _check_facing() -> void:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	root.add_child(camera)
	camera.position = Vector3(8, 8, 8)
	camera.look_at(Vector3.ZERO)
	camera.make_current()

	var world := World.instantiate()
	root.add_child(world)
	var state := State.create_initial("unit-animation-test")
	world.setup(state)
	var unit: Dictionary = state.units[0]
	var actors: Array = [unit, state.barbarians[0], state.animals[0]]
	var right_origin := {}
	var left_origin := {}
	var vertical_origin := {}
	var stationary_origin := {}
	var screen_right := camera.global_basis.x
	for actor: Dictionary in actors:
		var x: float = actor.position.x
		var y: float = actor.position.y
		var map_depth := screen_right.z / TerrainView.DEPTH_SCALE
		right_origin[actor.id] = {"x": x - screen_right.x, "y": y - map_depth}
		left_origin[actor.id] = {"x": x + screen_right.x, "y": y + map_depth}
		vertical_origin[actor.id] = {"x": x + screen_right.z, "y": y - screen_right.x / TerrainView.DEPTH_SCALE}
		stationary_origin[actor.id] = actor.position.duplicate()

	var sprites: Array[AnimatedSprite3D] = []
	for actor: Dictionary in actors:
		sprites.append(world._views[actor.id].get_node("Body/Sprite"))
	var right_facing := [false, false, false]
	world.sync(state, right_origin)
	for index in sprites.size():
		_check(sprites[index].flip_h == right_facing[index], "Rightward actor %d faces right" % index)
	var moving := sprites[0]
	moving.set_frame_and_progress(2, 0.4)
	world.sync(state, left_origin)
	for index in sprites.size():
		_check(sprites[index].flip_h != right_facing[index], "Leftward actor %d faces left" % index)
	_check(moving.animation == &"move" and moving.frame == 2 and is_equal_approx(moving.frame_progress, 0.4),
		"Turning preserves the current frame and progress")
	world.sync(state, vertical_origin)
	for index in sprites.size():
		_check(sprites[index].flip_h != right_facing[index], "Screen-vertical movement preserves actor %d facing" % index)
	world.sync(state, stationary_origin)
	_check(moving.animation == &"idle" and moving.flip_h, "Stopping preserves facing and resumes idle")
	unit.isCarried = true
	world.sync(state, right_origin)
	_check(moving.flip_h, "A carried minion preserves its facing")
	unit.isCarried = false
	camera.free()
	world.sync(state, right_origin)
	_check(moving.flip_h, "Movement without a camera preserves facing")
	world.free()

func _check_sheep_grazing() -> void:
	var session := Session.new("unit-animation-test")
	var state := session.state
	state.barbarians.clear()
	var sheep: Dictionary = state.animals[0]
	var world := World.instantiate()
	root.add_child(world)
	world.setup(state)
	var sprite: AnimatedSprite3D = world._views[sheep.id].get_node("Body/Sprite")
	for clip: StringName in [&"idle", &"move", &"graze"]:
		var expected: int = {&"idle": 6, &"move": 4, &"graze": 12}[clip]
		var frames := sprite.sprite_frames
		_check(frames.get_frame_count(clip) == expected and frames.get_animation_speed(clip) == 10.0
			and frames.get_animation_loop(clip) == (clip != &"graze"), "Sheep clip has correct timing: " + String(clip))
		for index in expected:
			var tile := frames.get_frame_texture(clip, index) as AtlasTexture
			_check(tile.region == Rect2(index * 128, 0, 128, 128), "Sheep atlas frames preserve order")
	_check(sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST and sprite.offset.y == -4.0,
		"Sheep preserves Nearest and its original visual support")

	session.advance(Session.FIXED_DT)
	var first_cycle: Dictionary = sheep.grazingCycle
	_check(first_cycle.phase == "patrol" and first_cycle.nextTick - state.tick in range(160, 181),
		"An old sheep without a cycle starts a staggered patrol")
	state.tick = first_cycle.nextTick - 1
	var position: Dictionary = sheep.position.duplicate()
	var destination: Dictionary = sheep.patrolTarget.duplicate()
	session.advance(Session.FIXED_DT)
	world.sync(state, session.previous_positions)
	_check(sheep.grazingCycle.phase == "rest" and sheep.position == position and sprite.animation == &"idle",
		"Patrol stops and shows idle while resting")
	state.tick = sheep.grazingCycle.nextTick - 1
	session.advance(Session.FIXED_DT)
	world.sync(state, session.previous_positions)
	_check(sheep.grazingCycle.phase == "graze" and sprite.animation == &"graze" and sprite.frame == 0,
		"Grazing starts on its first frame after idle")
	var start_tick: int = state.tick
	state.phase = "paused"
	session.advance(0.15)
	world.sync(state, session.previous_positions)
	_check(state.tick == start_tick and sprite.frame == 0, "Pausing freezes grazing")
	state.phase = "playing"
	session.speed_multiplier = 3
	session.advance(Session.FIXED_DT)
	world.sync(state, session.previous_positions)
	_check(state.tick > start_tick + 1 and sprite.frame == floori((state.tick - start_tick) * 0.5)
		and sheep.position == position, "Accelerated grazing advances frames while the sheep stays still")

	var saves := Saves.new("user://sheep-grazing-test-%d" % Time.get_ticks_usec())
	var written := saves.save_slot(1, state)
	var loaded := saves.read_slot(1)
	saves.delete_slot(1)
	_check(written.ok and loaded.status == "valid", "Grazing saves load successfully")
	if loaded.status == "valid":
		var loaded_sheep: Dictionary = loaded.save.gameState.animals[0]
		var cycle: Dictionary = loaded_sheep.grazingCycle
		_check(cycle.phase == "graze" and int(cycle.startTick) == int(sheep.grazingCycle.startTick)
			and int(cycle.nextTick) == int(sheep.grazingCycle.nextTick)
			and is_equal_approx(loaded_sheep.position.x, position.x)
			and is_equal_approx(loaded_sheep.position.y, position.y),
			"Loading preserves the grazing phase, its ticks and position")
		var resumed := Session.new()
		resumed.replace_state(loaded.save.gameState)
		resumed.advance(Session.FIXED_DT)
		_check(resumed.state.animals[0].grazingCycle.phase == "graze"
			and int(resumed.state.tick) == int(state.tick) + 1, "Loaded grazing resumes from the saved tick")

	session.speed_multiplier = 1
	var hunter: Dictionary = state.units[0]
	hunter.role = "hunter"
	var health: float = sheep.health
	Conflict._attack(state, hunter, sheep, {"damage": 1.0, "cooldownSeconds": 1.3}, "animal")
	for step in 15:
		session.advance(Session.FIXED_DT)
	_check(sheep.grazingCycle.phase == "graze" and sheep.health == health - 1.0 and sheep.position == position,
		"A hunter arrow can hit a sheep while it grazes")

	state.tick = sheep.grazingCycle.nextTick - 1
	_check(sheep.patrolTarget == destination, "Pauses preserve the previous patrol destination")
	session.advance(Session.FIXED_DT)
	world.sync(state, session.previous_positions)
	_check(sheep.grazingCycle.phase == "patrol" and sheep.grazingCycle.nextTick - state.tick == 160
		and sprite.animation != &"graze", "After grazing the sheep returns to patrol")
	sheep.isAlive = false
	sheep.respawnRemainingSeconds = Session.FIXED_DT
	session.advance(Session.FIXED_DT)
	_check(sheep.isAlive and not sheep.has("grazingCycle"), "Respawning clears the previous grazing cycle")
	session.advance(Session.FIXED_DT)
	_check(sheep.grazingCycle.phase == "patrol", "Respawned sheep begin a new patrol cycle")
	world.free()

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
