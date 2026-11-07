extends Node3D
## Replaceable provisional art. State owns positions, roles, health and quantity.

const COLORS := {
	"food": Color("d95c5c"), "wood": Color("9a6b43"), "stone": Color("c2c2bd"),
	"spark": Color("d79aff"), "gold": Color("e6bf5b"), "twigs": Color("79502f"),
	# Match BabylonGame.unitRoleColor so transformations remain recognizable.
	"gatherer": Color("f1d27a"), "lumberjack": Color("b98158"), "hunter": Color("8ed6d1"),
	"guardian": Color("d27575"), "artisan": Color("a5a5a2"), "mage": Color("a276ff"),
	"barbarian": Color("bd5d4b"), "sheep": Color("e0d4b8"),
}
@export var minion_scene: PackedScene = preload("res://scenes/actors/CharactersBase.tscn")
@export var actor_scenes := {
	"gatherer": preload("res://scenes/actors/Gatherer.tscn"),
	"lumberjack": preload("res://scenes/actors/Lumberjack.tscn"),
	"hunter": preload("res://scenes/actors/Hunter.tscn"),
	"guardian": preload("res://scenes/actors/Guardian.tscn"),
	"artisan": preload("res://scenes/actors/Artisan.tscn"),
	"mage": preload("res://scenes/actors/Mage.tscn"),
	"barbarian": preload("res://scenes/actors/Barbarian.tscn"),
	"sheep": preload("res://scenes/actors/Sheep.tscn"),
}
@export var resource_scenes := {
	"tree": preload("res://scenes/world/Tree.tscn"),
	"twigs": preload("res://scenes/world/Twigs.tscn"),
	"stone-vein": preload("res://scenes/world/Rock.tscn"),
	"ruin": preload("res://scenes/world/Spark.tscn"),
	"berry-bush": preload("res://scenes/world/Bush.tscn"),
}
@export var drop_scenes := {
	"food": preload("res://scenes/world/DropFood.tscn"),
	"wood": preload("res://scenes/world/DropWood.tscn"),
	"stone": preload("res://scenes/world/DropStone.tscn"),
	"spark": preload("res://scenes/world/DropSpark.tscn"),
	"gold": preload("res://scenes/world/DropGold.tscn"),
}
@export var biome_scenes := {
	"clearing": preload("res://scenes/world/BiomeClearing.tscn"),
	"meadow": preload("res://scenes/world/BiomeMeadow.tscn"),
	"forest": preload("res://scenes/world/BiomeForest.tscn"),
	"rocky": preload("res://scenes/world/BiomeRocky.tscn"),
	"ruins": preload("res://scenes/world/BiomeRuins.tscn"),
	"great-fire": preload("res://scenes/world/BiomeGreatFire.tscn"),
}
@export var decoration_scenes := {
	"grass": preload("res://scenes/world/Grass.tscn"),
	"mushroom": preload("res://scenes/world/Mushroom.tscn"),
	"flower-yellow": preload("res://scenes/world/FlowerYellow.tscn"),
	"flower-blue": preload("res://scenes/world/FlowerBlue.tscn"),
	"flower-gray": preload("res://scenes/world/FlowerGray.tscn"),
	"flower-pink": preload("res://scenes/world/FlowerPink.tscn"),
}
@export var campfire_scene: PackedScene = preload("res://scenes/world/Campfire.tscn")
@export var corpse_scene: PackedScene = preload("res://scenes/world/Corpse.tscn")
@export var barbarian_corpse_scene: PackedScene = preload("res://scenes/world/BarbarianCorpse.tscn")
@export var cloud_scene: PackedScene = preload("res://scenes/world/Cloud.tscn")
@export var heal_effect_scene: PackedScene = preload("res://scenes/world/HealEffect.tscn")
@export var alert_scene: PackedScene = preload("res://scenes/world/Alert.tscn")
var _views := {}
var _previous_positions := {}
var _alpha := 1.0
var _played_alerts := {}
var _alert_player: AudioStreamPlayer
var _alert_sound: AudioStreamWAV
var _command_radius := 10.0
var _totem_position := {"x": 80.0, "y": 80.0}
var _health_pixel_size := 0.05
var _health_screen_up := Vector3.UP

func setup(state: Dictionary) -> void:
	for child in get_children():
		child.free()
	_views.clear()
	_played_alerts.clear()
	_alert_player = AudioStreamPlayer.new()
	_alert_player.stream = _make_alert_sound()
	_alert_player.volume_db = 0
	add_child(_alert_player)
	for biome in state.biomes:
		var patch := _spawn(biome_scenes[biome.id], {"x": biome.region.x, "y": biome.region.y})
		patch.scale = Vector3(biome.region.size, 1, biome.region.size)
	for decoration in state.decorations:
		var key: String = "flower-" + decoration.get("flowerColor", "yellow") if decoration.kind == "flower" else decoration.kind
		var view := _spawn(decoration_scenes[key], decoration.position)
		view.scale = Vector3.ONE * decoration.scale
	sync(state)

func sync(state: Dictionary, previous_positions: Dictionary = {}, alpha: float = 1.0) -> void:
	_previous_positions = previous_positions
	_alpha = alpha
	var viewport := get_viewport()
	var camera := viewport.get_camera_3d()
	if camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		# KEEP_HEIGHT camera: one label pixel spans this many world metres.
		# Compensate zoom so HP keeps a readable screen size like the original HUD.
		_health_pixel_size = camera.size / maxf(viewport.get_visible_rect().size.y, 1.0)
		_health_screen_up = camera.global_basis.y
	_command_radius = state.totem.commandRadius
	_totem_position = state.totem.position
	var active := {}
	for unit in state.units:
		_sync_actor(unit, unit.role, active)
	for barbarian in state.barbarians:
		if barbarian.isAlive:
			_sync_actor(barbarian, "barbarian", active)
	for animal in state.animals:
		if animal.isAlive:
			_sync_actor(animal, "sheep", active)
	for resource in state.resources:
		if resource.amount > 0:
			active[resource.id] = true
			if not _views.has(resource.id):
				_views[resource.id] = _create_resource(resource)
	for drop in state.drops:
		if drop.amount > 0:
			active[drop.id] = true
			if not _views.has(drop.id):
				_views[drop.id] = _spawn(drop_scenes[drop.type], drop.position)
	_sync_survival_views(state, active)
	for id in _views.keys():
		if not active.has(id):
			_views[id].free()
			_views.erase(id)

func _sync_actor(actor: Dictionary, kind: String, active: Dictionary) -> void:
	active[actor.id] = true
	if _views.has(actor.id) and _views[actor.id].get_meta("kind") != kind:
		_views[actor.id].free()
		_views.erase(actor.id)
	if not _views.has(actor.id):
		var scene: PackedScene = actor_scenes.get(kind, minion_scene)
		var instance: Node3D = scene.instantiate()
		instance.set_meta("kind", kind)
		add_child(instance)
		_views[actor.id] = instance
	var previous: Dictionary = _previous_positions.get(actor.id, actor.position)
	var point := {"x": lerpf(previous.x, actor.position.x, _alpha), "y": lerpf(previous.y, actor.position.y, _alpha)}
	if kind == "hunter" and actor.task.kind == "combat":
		var dx: float = point.x - _totem_position.x
		var dy: float = point.y - _totem_position.y
		var distance := sqrt(dx * dx + dy * dy)
		var radius := minf(_command_radius, 10.0)
		if distance > radius and distance > 1e-8:
			point = {"x": clampf(_totem_position.x + dx / distance * radius, 2, 158), "y": clampf(_totem_position.y + dy / distance * radius, 2, 158)}
	_views[actor.id].position = Vector3(point.x, 0, point.y)
	var node: Node3D = _views[actor.id]
	if node.has_node("DetectionRange"):
		var radius := maxf(_command_radius, 0) * 1.05
		node.get_node("DetectionRange").scale = Vector3(radius, 1, radius)
	node.present_health(actor, _health_pixel_size, _health_screen_up)
	node.present(actor)

func _sync_survival_views(state: Dictionary, active: Dictionary) -> void:
	for campfire in state.campfires:
		active[campfire.id] = true
		if not _views.has(campfire.id):
			var node := _spawn(campfire_scene, campfire.position)
			var radius: float = campfire.healingRadius * 1.05
			var ring: Node3D = node.find_child("HealingRange", true, false)
			if ring != null:
				ring.scale = Vector3(radius, 1, radius)
			_views[campfire.id] = node
	for corpse in state.corpses + state.barbarianCorpses:
		active[corpse.id] = true
		if not _views.has(corpse.id):
			_views[corpse.id] = _spawn(barbarian_corpse_scene if corpse in state.barbarianCorpses else corpse_scene, corpse.position)
	for id in _views:
		var actor_view: Node3D = _views[id]
		if actor_view.has_method("reset_feedback"):
			actor_view.reset_feedback()
	for effect in state.effects:
		if effect.kind == "heal-crosses":
			active[effect.id] = true
			if not _views.has(effect.id):
				_views[effect.id] = _spawn(heal_effect_scene, effect.position)
			var point: Dictionary = effect.position
			for unit in state.units:
				if unit.id == effect.targetId:
					point = unit.position
					break
			if _views[effect.id].has_method("present"):
				_views[effect.id].present(effect, point)
		elif _views.has(effect.targetId) and _views[effect.targetId].has_method("flash"):
			var node: Node3D = _views[effect.targetId]
			if effect.kind == "damage-flash":
				node.flash(Color("ef5b5b"))
			elif effect.kind == "attack-lunge":
				var direction := Vector3(effect.position.x - node.position.x, 0, effect.position.y - node.position.z).normalized()
				node.lunge(direction, sin(clampf(effect.ageSeconds / effect.durationSeconds, 0, 1) * PI) * 0.2)
	for alert in state.alerts:
		active[alert.id] = true
		if not _views.has(alert.id):
			_views[alert.id] = _spawn(alert_scene, alert.position)
		var point := Vector3(alert.position.x, 0, alert.position.y)
		if _views.has(alert.detectorId):
			point = _views[alert.detectorId].position
		if _views[alert.id].has_method("present"):
			_views[alert.id].present(point, alert.ageSeconds / alert.durationSeconds)
		if alert.playSound and not _played_alerts.has(alert.id):
			_played_alerts[alert.id] = true
			_alert_player.play()
	for cloud in state.weather.clouds:
		active[cloud.id] = true
		if not _views.has(cloud.id):
			_views[cloud.id] = _spawn(cloud_scene, cloud.position)
		var previous: Dictionary = _previous_positions.get(cloud.id, cloud.position)
		_views[cloud.id].position = Vector3(lerpf(previous.x, cloud.position.x, _alpha), 0, lerpf(previous.y, cloud.position.y, _alpha))
		if _views[cloud.id].has_method("present"):
			_views[cloud.id].present(cloud)

func _make_alert_sound() -> AudioStreamWAV:
	if _alert_sound != null:
		return _alert_sound
	var samples := PackedByteArray()
	var count := 3308
	samples.resize(count * 2)
	var phase := 0.0
	for index in count:
		var time := float(index) / 22050.0
		var frequency := 880.0 * pow(620.0 / 880.0, minf(time / 0.11, 1.0))
		phase += TAU * frequency / 22050.0
		var envelope: float
		if time <= 0.012:
			envelope = 0.0001 * pow(0.08 / 0.0001, time / 0.012)
		elif time <= 0.14:
			envelope = 0.08 * pow(0.0001 / 0.08, (time - 0.012) / 0.128)
		else:
			envelope = 0.0001
		samples.encode_s16(index * 2, int((2.0 / PI) * asin(sin(phase)) * envelope * 32767))
	_alert_sound = AudioStreamWAV.new()
	_alert_sound.format = AudioStreamWAV.FORMAT_16_BITS
	_alert_sound.mix_rate = 22050
	_alert_sound.data = samples
	return _alert_sound

func pick_unit(camera: Camera3D, screen_point: Vector2, units: Array) -> String:
	var selected := ""
	var nearest := INF
	var origin := camera.project_ray_origin(screen_point)
	var direction := camera.project_ray_normal(screen_point)
	for unit in units:
		if not _views.has(unit.id):
			continue
		var hit: Variant = _views[unit.id].pick_ray(origin, direction)
		if hit is Vector3:
			var distance: float = origin.distance_squared_to(hit)
			if distance < nearest:
				nearest = distance
				selected = unit.id
	if not selected.is_empty():
		return selected
	# Same screen-space tolerance as the original drag-to-equip interaction.
	for unit in units:
		if not _views.has(unit.id):
			continue
		var center: Vector3 = _views[unit.id].position + Vector3(0, 0.65, 0)
		var screen_center := camera.unproject_position(center)
		var screen_edge := camera.unproject_position(center + Vector3(1.25, 0, 0))
		var radius := maxf(absf(screen_edge.x - screen_center.x), 24.0)
		var distance := screen_point.distance_to(screen_center)
		if distance <= radius and distance < nearest:
			nearest = distance
			selected = unit.id
	return selected

func _create_resource(resource: Dictionary) -> Node3D:
	return _spawn(resource_scenes[resource.source], resource.position)

func _spawn(scene: PackedScene, point: Dictionary) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.position = Vector3(point.x, 0, point.y)
	add_child(node)
	return node
