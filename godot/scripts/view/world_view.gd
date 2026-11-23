extends Node3D
## Replaceable provisional art. State owns positions, roles, health and quantity.

const AppearanceRandom = preload("res://scripts/simulation/seeded_random.gd")
const Occlusion = preload("res://scripts/view/sprite_occlusion.gd")
const DECORATION_VARIANTS := {
	"grass": ["grass-small", "grass"],
	"mushroom": ["mushroom-small", "mushroom", "mushroom-big"],
	"bush": ["bush-small", "bush", "bush-big"],
}

const Footprint = preload("res://scripts/simulation/biome_footprint.gd")

const COLORS := {
	"food": Color("d95c5c"), "wood": Color("9a6b43"), "stone": Color("c2c2bd"),
	"spark": Color("d79aff"), "gold": Color("e6bf5b"), "twigs": Color("79502f"),
	# Match BabylonGame.unitRoleColor so transformations remain recognizable.
	"gatherer": Color("f1d27a"), "lumberjack": Color("b98158"), "hunter": Color("8ed6d1"),
	"guardian": Color("d27575"), "artisan": Color("a5a5a2"), "mage": Color("a276ff"),
	"barbarian": Color("bd5d4b"), "sheep": Color("e0d4b8"),
}
@export var mage_projectile_scene: PackedScene = preload("res://scenes/world/MageProjectile.tscn")
@export var hunter_projectile_scene: PackedScene = preload("res://scenes/world/HunterProjectile.tscn")
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
	"berry-bush": preload("res://scenes/world/BerryBush.tscn"),
}
@export var tree_scenes := {
	"tree-1": preload("res://scenes/world/Tree.tscn"),
	"tree-2": preload("res://scenes/world/Tree2.tscn"),
	"tree-3": preload("res://scenes/world/Tree3.tscn"),
	"tree-4": preload("res://scenes/world/Tree4.tscn"),
}
@export var large_resource_scenes := {
	"stone-vein": preload("res://scenes/world/RockLarge.tscn"),
	"ruin": preload("res://scenes/world/SparkLarge.tscn"),
}
@export var drop_scenes := {
	"food": preload("res://scenes/world/DropFood.tscn"),
	"berries": preload("res://scenes/world/DropBerries.tscn"),
	"wood": preload("res://scenes/world/DropWood.tscn"),
	"stone": preload("res://scenes/world/DropStone.tscn"),
	"spark": preload("res://scenes/world/DropSpark.tscn"),
	"gold": preload("res://scenes/world/DropGold.tscn"),
}
@export var biome_scenes := {
	"clearing": preload("res://scenes/world/BiomeClearing.tscn"),
	"mountain": preload("res://scenes/world/BiomeMountain.tscn"),
	"meadow": preload("res://scenes/world/BiomeMeadow.tscn"),
	"forest": preload("res://scenes/world/BiomeForest.tscn"),
	"rocky": preload("res://scenes/world/BiomeRocky.tscn"),
	"ruins": preload("res://scenes/world/BiomeRuins.tscn"),
	"great-fire": preload("res://scenes/world/BiomeGreatFire.tscn"),
}
@export var water_rock_scenes: Array[PackedScene] = [
	preload("res://scenes/world/WaterRock1.tscn"), preload("res://scenes/world/WaterRock2.tscn"),
	preload("res://scenes/world/WaterRock3.tscn"), preload("res://scenes/world/WaterRock4.tscn"),
	preload("res://scenes/world/WaterRock5.tscn"), preload("res://scenes/world/WaterRock6.tscn"),
	preload("res://scenes/world/WaterRock7.tscn"), preload("res://scenes/world/WaterRock8.tscn"),
]
@export var decoration_scenes := {
	"grass": preload("res://scenes/world/Grass.tscn"),
	"grass-small": preload("res://scenes/world/GrassSmall.tscn"),
	"mushroom": preload("res://scenes/world/Mushroom.tscn"),
	"mushroom-small": preload("res://scenes/world/MushroomSmall.tscn"),
	"mushroom-big": preload("res://scenes/world/MushroomBig.tscn"),
	"bush": preload("res://scenes/world/DecorationBush.tscn"),
	"bush-small": preload("res://scenes/world/DecorationBushSmall.tscn"),
	"bush-big": preload("res://scenes/world/DecorationBushBig.tscn"),
	"bush-forest": preload("res://scenes/world/DecorationBushForest.tscn"),
	"bush-forest-big": preload("res://scenes/world/DecorationBushForestBig.tscn"),
}
@export var campfire_scene: PackedScene = preload("res://scenes/world/Campfire.tscn")
@export var corpse_scene: PackedScene = preload("res://scenes/world/Corpse.tscn")
@export var barbarian_corpse_scene: PackedScene = preload("res://scenes/world/BarbarianCorpse.tscn")
@export var cloud_scene: PackedScene = preload("res://scenes/world/Cloud.tscn")
@export var cloud_variants: Array[PackedScene] = [
	preload("res://scenes/world/Cloud.tscn"),
	preload("res://scenes/world/Cloud2.tscn"),
	preload("res://scenes/world/Cloud3.tscn"),
	preload("res://scenes/world/Cloud4.tscn"),
]
@export var heal_effect_scene: PackedScene = preload("res://scenes/world/HealEffect.tscn")
@export var alert_scene: PackedScene = preload("res://scenes/world/Alert.tscn")
var _views := {}
var _previous_positions := {}
var _alpha := 1.0
var _hunter_render_tick := 0.0
var _played_alerts := {}
var _alert_player: AudioStreamPlayer
var _alert_sound: AudioStreamWAV
var _command_radius := 10.0
var _totem_position := {"x": 80.0, "y": 80.0}
var carried_preview: Dictionary = {}
var _health_pixel_size := 0.05
var _health_screen_up := Vector3.UP
var _occlusion := Occlusion.new()
var _resource_clearances: Array[Vector3] = []
var _decoration_occluders: Array[Node3D] = []

const HunterImpactScene = preload("res://scenes/world/HunterImpact.tscn")
const HunterImpactDust = preload("res://assets/vfx/hunter_impact_dust.png")
const TerrainView = preload("res://scripts/view/terrain_projection.gd")
const IslandSurface = preload("res://scenes/world/IslandSurface.tscn")
var _terrain: Array = []

func setup(state: Dictionary) -> void:
	for child in get_children():
		child.free()
	_views.clear()
	_hunter_render_tick = state.tick
	_decoration_occluders.clear()
	_resource_clearances.clear()
	_occlusion = Occlusion.new()
	_played_alerts.clear()
	_alert_player = AudioStreamPlayer.new()
	_alert_player.stream = _make_alert_sound()
	_alert_player.volume_db = 0
	add_child(_alert_player)
	_terrain = state.terrain
	var surface := IslandSurface.instantiate()
	add_child(surface)
	surface.build(state)
	# Include depleted nodes so rain/load does not change decorative placement.
	for resource in state.resources:
		var view := _create_resource(resource, state.seed)
		_resource_clearances.append(Vector3(resource.position.x, resource.position.y, view.decoration_clearance_radius))
		if resource.amount > 0:
			_views[resource.id] = view
		else:
			view.free()
	for decoration in state.decorations:
		if decoration.kind == "water-rock":
			var random := AppearanceRandom.new(state.seed + ":" + decoration.id)
			var rock := _spawn(water_rock_scenes[random.next_int(0,water_rock_scenes.size()-1)],decoration.position) as AnimatedSprite3D
			# Lift the billboard clear of the water plane without shifting its projected centre.
			rock.position += Vector3(0,0.65,0.65 / tan(TerrainView.PITCH))
			rock.set_frame_and_progress(random.next_int(0,rock.sprite_frames.get_frame_count("default")-1),0.0)
		else:
			_create_decoration(decoration, state.seed, state.biomes)
	sync(state, {}, 0.0)

func _create_decoration(decoration: Dictionary, seed_text: String, biomes: Array = []) -> void:
	# Appearance has its own PRNG: changing art never consumes simulation randomness.
	# Retired decoration types in a loaded world have no visual representation.
	if not DECORATION_VARIANTS.has(decoration.kind):
		return
	var random := AppearanceRandom.new(seed_text + ":" + decoration.id + ":appearance")
	var variants: Array = DECORATION_VARIANTS[decoration.kind]
	var key: String = variants[random.next_int(0, variants.size() - 1)]
	if decoration.get("biome", "") == "forest":
		if key == "bush":
			key = "bush-forest"
		elif key == "bush-big":
			key = "bush-forest-big"
	var view := _spawn(decoration_scenes[key], decoration.position)
	_prepare_ground_sprite(view.get_node_or_null("Visual/Default/Sprite"))
	view.scale = Vector3.ONE * decoration.scale
	var sprite := view.get_node_or_null("Visual/Default/Sprite") as SpriteBase3D
	if sprite != null:
		sprite.flip_h = random.next_int(0, 1) == 1
	view.set_meta("decoration_id", decoration.id)
	if not biomes.is_empty() and not decoration.get("grouped",false):
		var radius: float = view.decoration_clearance_radius * decoration.scale
		var point := Vector2(decoration.position.x, decoration.position.y)
		if not _decoration_fits(point, radius):
			var region: Dictionary = {}
			for biome in biomes:
				if biome.instanceId == decoration.get("biomeInstanceId", ""):
					region = biome.region
					break
			var placed := false
			if not region.is_empty():
				var placement := AppearanceRandom.new(seed_text + ":" + decoration.id + ":visual-clearance")
				for attempt in 12:
					var sample := Footprint.sample(region, placement, region.get("spawnCells",region.cells))
					var candidate := Vector2(sample.x, sample.y)
					if _decoration_fits(candidate, radius):
						view.position = TerrainView.world(sample,_terrain)
						placed = true
						break
			if not placed:
				view.free()
				return
	if view.has_method("update_holes"):
		_decoration_occluders.append(view)

func _decoration_fits(point: Vector2, radius: float) -> bool:
	for footprint in _resource_clearances:
		if point.distance_squared_to(Vector2(footprint.x, footprint.y)) < pow(radius + footprint.z, 2):
			return false
	return true

func update_occlusion(camera: Camera3D, delta: float) -> void:
	if camera == null or camera.projection != Camera3D.PROJECTION_ORTHOGONAL:
		return
	var bodies: Array[PackedVector3Array] = []
	var body_ids: Array[int] = []
	for view in _views.values():
		# Only actor bodies; HP, detection rings and feedback are excluded.
		if view.get_meta("kind", "") in ["gatherer", "lumberjack", "hunter", "guardian", "artisan", "mage", "barbarian"]:
			var sprite := view.get_node_or_null("Body/Sprite") as SpriteBase3D
			if sprite != null:
				bodies.append(_occlusion.sprite_samples(sprite, camera))
				body_ids.append(view.get_instance_id())
	var body_bounds: Array[Rect2] = []
	for points in bodies:
		body_bounds.append(_occlusion.projected_bounds(points, camera))
	for view in _views.values() + _decoration_occluders:
		if not is_instance_valid(view) or not view.has_method("update_holes"):
			continue
		if not view.dither_enabled:
			continue
		var sprite: SpriteBase3D = view.canopy_sprite()
		var targets := {}
		if sprite != null:
			var bounds := _occlusion.sprite_bounds(sprite, camera)
			for index in bodies.size():
				# Most trees cannot overlap this body. Avoid scanning their pixels.
				if not bounds.intersects(body_bounds[index]):
					continue
				if view.center_on_overlap:
					# Pick an actual occluded body sample, never transparent atlas padding.
					var point: Variant = _occlusion.covered_point(sprite, view.canopy_region, bodies[index], camera, body_bounds[index].get_center())
					if point != null:
						targets[body_ids[index]] = point
				elif _occlusion.covers(sprite, view.canopy_region, bodies[index], camera):
					var center: Vector2 = body_bounds[index].get_center()
					var depth := bodies[index][0].dot(camera.global_basis.z)
					targets[body_ids[index]] = camera.global_basis.x * center.x + camera.global_basis.y * center.y + camera.global_basis.z * depth
		view.update_holes(targets, camera, delta)

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
		_sync_actor(unit, unit.role, active, camera)
	for barbarian in state.barbarians:
		if barbarian.isAlive:
			_sync_actor(barbarian, "barbarian", active, camera)
	for animal in state.animals:
		if animal.isAlive:
			var cycle: Dictionary = animal.get("grazingCycle", {})
			# At 20 ticks per second each 10 FPS grazing frame lasts two ticks.
			var graze_frame := floori((state.tick - cycle.startTick) * 0.5) if cycle.get("phase") == "graze" else -1
			_sync_actor(animal, "sheep", active, camera, graze_frame)
	for resource in state.resources:
		if resource.amount > 0:
			active[resource.id] = true
			if not _views.has(resource.id):
				_views[resource.id] = _create_resource(resource, state.seed)
	for drop in state.drops:
		if drop.amount > 0:
			active[drop.id] = true
			if not _views.has(drop.id):
				var appearance: String = drop.get("appearance", drop.type)
				if appearance == "food" and not drop.has("launchTick"):
					for resource in state.resources:
						if resource.id == drop.get("sourceNodeId") and resource.source == "berry-bush":
							appearance = "berries"
							break
				var scene: PackedScene = drop_scenes.get(appearance, drop_scenes[drop.type])
				var spawned := _spawn(scene, drop.position)
				_prepare_ground_sprite(spawned.get_node_or_null("Visual/Default/Sprite"))
				_views[drop.id] = spawned
			var view: Node3D = _views[drop.id]
			if view.has_method("present_drop"):
				var tick_fraction := 0.0 if state.phase == "paused" else clampf(alpha, 0.0, 1.0)
				view.present_drop(drop, state.tick + tick_fraction, _terrain)
	_sync_survival_views(state, active)
	for id in _views.keys():
		if not active.has(id):
			_views[id].free()
			_views.erase(id)

func _sync_actor(actor: Dictionary, kind: String, active: Dictionary, camera: Camera3D, graze_frame: int = -1) -> void:
	active[actor.id] = true
	if _views.has(actor.id) and _views[actor.id].get_meta("kind") != kind:
		_views[actor.id].free()
		_views.erase(actor.id)
	if not _views.has(actor.id):
		var scene: PackedScene = actor_scenes.get(kind, minion_scene)
		var instance: Node3D = scene.instantiate()
		instance.set_meta("kind", kind)
		add_child(instance)
		_prepare_ground_sprite(instance.get_node_or_null("Body/Sprite"))
		_views[actor.id] = instance
	var previous: Dictionary = _previous_positions.get(actor.id, actor.position)
	var point := {"x": lerpf(previous.x, actor.position.x, _alpha), "y": lerpf(previous.y, actor.position.y, _alpha)}
	if actor.get("isCarried", false):
		point = carried_preview.position if carried_preview.get("unitId") == actor.id and carried_preview.get("position") != null else actor.position
	_views[actor.id].position = TerrainView.world(point,_terrain)
	var node: Node3D = _views[actor.id]
	if node.has_node("DetectionRange"):
		var radius := maxf(_command_radius, 0) * 1.05
		node.get_node("DetectionRange").scale = Vector3(radius, 1, radius)
	node.present_health(actor, _health_pixel_size, _health_screen_up)
	var displacement := Vector2(actor.position.x - previous.x, actor.position.y - previous.y)
	var horizontal := 0.0
	if camera != null:
		var world_motion := Vector3(displacement.x, 0.0, displacement.y * TerrainView.DEPTH_SCALE)
		horizontal = world_motion.dot(camera.global_basis.x)
	node.present(actor, displacement.length_squared() > 1e-8, horizontal, graze_frame)

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
		if effect.kind in ["hunter-impact", "hunter-miss"]:
			_present_hunter_impact(effect, active)
		elif effect.kind == "heal-crosses":
			active[effect.id] = true
			if not _views.has(effect.id):
				_views[effect.id] = _spawn(heal_effect_scene, effect.position)
			var point := TerrainView.world(effect.position, _terrain)
			if _views.has(effect.targetId):
				# Match the visible actor, including interpolation between simulation ticks.
				var target: Node3D = _views[effect.targetId]
				point = target.position
			if _views[effect.id].has_method("present"):
				_views[effect.id].present(effect, point)
		elif _views.has(effect.targetId) and _views[effect.targetId].has_method("flash"):
			var node: Node3D = _views[effect.targetId]
			if effect.kind == "damage-flash":
				node.flash(Color("ef5b5b"))
			elif effect.kind == "attack-lunge":
				var kind: String = node.get_meta("kind", "")
				if kind == "hunter":
					continue
				if node.has_method("present_attack"):
					node.present_attack(effect.id)
				if kind == "mage":
					active[effect.id] = true
					if not _views.has(effect.id):
						_views[effect.id] = _spawn(mage_projectile_scene, effect.position)
					var origin := node.position + Vector3(0, 0.8, 0)
					var destination := TerrainView.world(effect.position,_terrain) + Vector3.UP * 0.8
					_views[effect.id].position = origin.lerp(destination, clampf(effect.ageSeconds / effect.durationSeconds, 0, 1))
					if origin.distance_squared_to(destination) > 1e-8:
						_views[effect.id].look_at(_views[effect.id].position + destination - origin, Vector3.UP)
				else:
					var direction := TerrainView.world(effect.position, _terrain) - node.position
					direction = Vector3(direction.x, 0, direction.z).normalized()
					node.lunge(direction, sin(clampf(effect.ageSeconds / effect.durationSeconds, 0, 1) * PI) * 0.2)
	_present_hunter_shots(state, active)
	for alert in state.alerts:
		active[alert.id] = true
		if not _views.has(alert.id):
			_views[alert.id] = _spawn(alert_scene, alert.position)
		var point := TerrainView.world(alert.position,_terrain)
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
			var appearance := AppearanceRandom.new(state.seed + ":" + cloud.id + ":cloud-appearance")
			var scene := cloud_scene if cloud_variants.is_empty() else cloud_variants[appearance.next_int(0, cloud_variants.size() - 1)]
			_views[cloud.id] = _spawn(scene, cloud.position)
		var previous: Dictionary = _previous_positions.get(cloud.id, cloud.position)
		_views[cloud.id].position = TerrainView.world({"x":lerpf(previous.x, cloud.position.x, _alpha), "y":lerpf(previous.y, cloud.position.y, _alpha)},_terrain)
		if _views[cloud.id].has_method("present"):
			_views[cloud.id].present(cloud)

func _present_hunter_shots(state: Dictionary, active: Dictionary) -> void:
	if state.phase == "playing":
		_hunter_render_tick = state.tick + clampf(_alpha, 0.0, 0.999999)
	else:
		_hunter_render_tick = clampf(_hunter_render_tick, state.tick, state.tick + 1.0)
	var render_tick := _hunter_render_tick
	var camera := get_viewport().get_camera_3d()
	for shot: Dictionary in state.get("hunterShots", []):
		var aim := TerrainView.world(shot.aim, _terrain)
		var hunter: Node3D = _views.get(shot.hunterId)
		if active.has(shot.hunterId) and hunter.get_meta("kind", "") == "hunter" and hunter.has_method("present_hunter_draw"):
			var horizontal := (aim - hunter.position).dot(camera.global_basis.x) if camera != null else 0.0
			var clip_frame: float = 5.0 * (render_tick - shot.startTick) / (shot.releaseTick - shot.startTick)
			hunter.present_hunter_draw(clip_frame, horizontal)
		if not shot.has("origin") or render_tick >= shot.impactTick:
			continue
		active[shot.id] = true
		if not _views.has(shot.id):
			var projectile := _spawn(hunter_projectile_scene, shot.origin)
			var source: Node3D = hunter if active.has(shot.hunterId) and hunter.get_meta("kind", "") == "hunter" else null
			var launch := _hunter_arrow_launch(source, projectile.position, aim, camera)
			projectile.set_meta("launch_transform", launch)
			_views[shot.id] = projectile
		var arrow: Node3D = _views[shot.id]
		var launch: Transform3D = arrow.get_meta("launch_transform")
		var origin := launch.origin
		var destination := aim + Vector3.UP * 0.8
		var direction := destination - origin
		var progress: float = clampf((render_tick - shot.releaseTick) / (shot.impactTick - shot.releaseTick), 0.0, 1.0)
		var tip_offset := direction.limit_length(0.45)
		arrow.position = origin.lerp(destination - tip_offset, progress)
		var axes := camera.global_basis if camera != null else Basis.IDENTITY
		var launch_angle := atan2(launch.basis.x.dot(axes.y), launch.basis.x.dot(axes.x))
		var flight_angle := atan2(direction.dot(axes.y), direction.dot(axes.x))
		var alignment := smoothstep(0.0, 0.4, progress)
		var angle := lerp_angle(launch_angle, flight_angle, alignment)
		if camera != null:
			# Keep the arrow in front of the bow while their sprites overlap.
			arrow.global_position += axes.z * (0.06 * (1.0 - alignment))
		arrow.global_basis = axes.rotated(axes.z, angle)

func _hunter_arrow_launch(hunter: Node3D, ground: Vector3, aim: Vector3, camera: Camera3D) -> Transform3D:
	var axes := camera.global_basis if camera != null else Basis.IDENTITY
	var facing := -1.0 if (aim - ground).dot(axes.x) < 0.0 else 1.0
	var socket := Vector3(0.6084676, 1.2244949, 0.0)
	var angle := deg_to_rad(30.0)
	if hunter != null:
		var marker := hunter.get_node_or_null("Body/Sprite/ArrowSpawn") as Marker3D
		if marker != null:
			var sprite := marker.get_parent() as Node3D
			ground += sprite.global_position - hunter.global_position
			socket = marker.position * sprite.global_basis.get_scale().abs()
			angle = marker.rotation.z
	socket.x *= facing
	return Transform3D(axes.rotated(axes.z, PI - angle if facing < 0.0 else angle), ground + axes * socket)

func _present_hunter_impact(effect: Dictionary, active: Dictionary) -> void:
	active[effect.id] = true
	var hit: bool = effect.kind == "hunter-impact"
	if not _views.has(effect.id):
		var marker := _spawn(HunterImpactScene, effect.position) as Sprite3D
		marker.position.y += 0.8 if hit else 0.12
		if not hit:
			marker.texture = HunterImpactDust
			marker.hframes = 8
		_views[effect.id] = marker
	var marker: Sprite3D = _views[effect.id]
	var progress: float = clampf(effect.ageSeconds / effect.durationSeconds, 0.0, 1.0)
	if hit:
		var target: Node3D = _views.get(effect.targetId)
		if active.has(effect.targetId) and target.has_method("flash"):
			target.flash(Color("ef5b5b"))
		marker.scale = Vector3.ONE * lerpf(0.55, 1.0, progress)
	else:
		marker.frame = mini(floori(progress * marker.hframes), marker.hframes - 1)
	marker.modulate.a = 1.0 - progress

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

func carried_body_rect(camera: Camera3D, unit_id: String, ground: Dictionary) -> Rect2:
	var view: Node3D = _views[unit_id]
	var shape: CollisionShape3D = view.get_node("Selection/Shape")
	var half: Vector3 = shape.shape.size * 0.5
	var lift: Vector3 = (TerrainView.world(ground,_terrain) + Vector3.UP * view.carried_height) - view.global_position
	var bounds := Rect2(camera.unproject_position(shape.global_position + lift), Vector2.ZERO)
	for x in [-half.x, half.x]:
		for y in [-half.y, half.y]:
			for z in [-half.z, half.z]:
				bounds = bounds.expand(camera.unproject_position(shape.to_global(Vector3(x, y, z)) + lift))
	return bounds

func carried_screen_offset(camera: Camera3D, unit_id: String) -> Vector2:
	if not _views.has(unit_id):
		return Vector2.ZERO
	var view: Node3D = _views[unit_id]
	var lifted := view.to_global(Vector3.UP * view.carried_height)
	return camera.unproject_position(lifted) - camera.unproject_position(view.global_position)

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

func _create_resource(resource: Dictionary, seed_text: String) -> Node3D:
	var scene: PackedScene = resource_scenes[resource.source]
	if resource.source == "tree":
		var random := AppearanceRandom.new(seed_text + ":" + resource.id + ":tree-appearance")
		var first := 3 if resource.get("biome", "") == "meadow" else 1
		scene = tree_scenes["tree-%d" % (first + random.next_int(0, 1))]
	elif large_resource_scenes.has(resource.source):
		# Equal visual chances, stable per node and independent of simulation RNG.
		# Size does not affect tier, amount, yield or interaction radius yet.
		var random := AppearanceRandom.new(seed_text + ":" + resource.id + ":resource-appearance")
		if random.next_int(0, 1) == 1:
			scene = large_resource_scenes[resource.source]
	var view := _spawn(scene, resource.position)
	_prepare_ground_sprite(view.get_node_or_null("Visual/Default/Sprite"))
	return view

func _prepare_ground_sprite(sprite: SpriteBase3D) -> void:
	if sprite == null or sprite.billboard != BaseMaterial3D.BILLBOARD_ENABLED or sprite.material_override != null:
		return
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/standing_sprite.gdshader")
	sprite.material_override = material
	sprite.set_meta("standing_material", material)
	var refresh := func() -> void:
		var texture := _occlusion.texture(sprite)
		if texture is AtlasTexture:
			texture = texture.atlas
		material.set_shader_parameter("sprite_texture", texture)
	refresh.call()
	if sprite is AnimatedSprite3D:
		sprite.frame_changed.connect(refresh)
		sprite.animation_changed.connect(refresh)
		sprite.sprite_frames_changed.connect(refresh)
	elif sprite is Sprite3D:
		sprite.texture_changed.connect(refresh)

func _spawn(scene: PackedScene, point: Dictionary) -> Node3D:
	var node := scene.instantiate() as Node3D
	node.position = TerrainView.world(point,_terrain)
	add_child(node)
	return node
