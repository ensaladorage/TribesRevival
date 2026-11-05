extends Node3D
## Replaceable provisional art. State owns positions, roles, health and quantity.

const COLORS := {
	"food": Color("bc4770"), "wood": Color("6b964b"), "stone": Color("8b919a"),
	"spark": Color("73e9e9"), "gold": Color("e3bf54"), "twigs": Color("94613d"),
	"gatherer": Color("ece3bd"), "lumberjack": Color("dd8d4c"), "hunter": Color("71ac8f"),
	"guardian": Color("87a9c9"), "artisan": Color("b294c7"), "mage": Color("96dbe0"),
	"barbarian": Color("bd5d4b"), "rabbit": Color("e0d4b8"),
}
const BIOME_COLORS := {"clearing": Color("5c7447"), "meadow": Color("648547"), "forest": Color("3f623e"), "rocky": Color("686d64"), "ruins": Color("526c68")}
var _views := {}
var _materials := {}
var _previous_positions := {}
var _alpha := 1.0
var _played_alerts := {}
var _alert_player: AudioStreamPlayer
var _alert_sound: AudioStreamWAV

func setup(state: Dictionary) -> void:
	for child in get_children():
		child.free()
	_views.clear()
	_played_alerts.clear()
	_alert_player = AudioStreamPlayer.new()
	_alert_player.stream = _make_alert_sound()
	_alert_player.volume_db = -12
	add_child(_alert_player)
	for biome in state.biomes:
		var disc := CylinderMesh.new()
		disc.top_radius = biome.region.size / 2.0
		disc.bottom_radius = disc.top_radius
		disc.height = 0.02
		disc.radial_segments = 48
		_mesh(self, disc, Vector3(biome.region.x, 0.005, biome.region.y), BIOME_COLORS.get(biome.id, Color("546446")))
	for decoration in state.decorations:
		var stem := BoxMesh.new()
		stem.size = Vector3(0.12, 0.18, 0.12) * decoration.scale
		var color := Color("91a957")
		if decoration.kind == "flower":
			color = {"yellow": Color("e8cd65"), "blue": Color("7eb0d3"), "gray": Color("b6b9b7"), "pink": Color("e879b9")}.get(decoration.get("flowerColor", "yellow"), color)
		elif decoration.kind == "mushroom":
			color = Color("c29b80")
		_mesh(self, stem, Vector3(decoration.position.x, 0.1, decoration.position.y), color)
	sync(state)

func sync(state: Dictionary, previous_positions: Dictionary = {}, alpha: float = 1.0) -> void:
	_previous_positions = previous_positions
	_alpha = alpha
	var active := {}
	for unit in state.units:
		_sync_actor(unit, unit.role, active)
	for barbarian in state.barbarians:
		if barbarian.isAlive:
			_sync_actor(barbarian, "barbarian", active)
	for animal in state.animals:
		if animal.isAlive:
			_sync_actor(animal, "rabbit", active)
	for resource in state.resources:
		if resource.amount > 0:
			active[resource.id] = true
			if not _views.has(resource.id):
				_views[resource.id] = _create_resource(resource)
	for drop in state.drops:
		if drop.amount > 0:
			active[drop.id] = true
			if not _views.has(drop.id):
				var node := Node3D.new()
				add_child(node)
				var cube := BoxMesh.new()
				cube.size = Vector3(0.35, 0.35, 0.35)
				_mesh(node, cube, Vector3(0, 0.18, 0), COLORS[drop.type])
				node.position = Vector3(drop.position.x, 0, drop.position.y)
				_views[drop.id] = node
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
		var node := Node3D.new()
		node.set_meta("kind", kind)
		add_child(node)
		var body := CapsuleMesh.new()
		body.radius = 0.36 if kind != "rabbit" else 0.24
		body.height = 1.3 if kind != "rabbit" else 0.5
		var body_view := _mesh(node, body, Vector3(0, body.height / 2.0, 0), COLORS.get(kind, Color.WHITE))
		body_view.name = "Body"
		body_view.set_meta("rest_height", body.height / 2.0)
		if kind != "rabbit":
			var health := Label3D.new()
			health.name = "Health"
			health.position.y = 2.1
			health.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			health.font_size = 30
			health.pixel_size = 0.006
			node.add_child(health)
		_create_role_tool(node, kind)
		_views[actor.id] = node
	var previous: Dictionary = _previous_positions.get(actor.id, actor.position)
	_views[actor.id].position = Vector3(lerpf(previous.x, actor.position.x, _alpha), 0, lerpf(previous.y, actor.position.y, _alpha))
	var node: Node3D = _views[actor.id]
	if node.has_node("Health"):
		node.get_node("Health").text = "%s / %s" % [actor.health, actor.maxHealth]
	if actor.get("hasShield", false) and not node.has_node("Shield"):
		var shield := CylinderMesh.new()
		shield.top_radius = 0.3
		shield.bottom_radius = 0.3
		shield.height = 0.1
		var view := _mesh(node, shield, Vector3(-0.43, 0.85, 0), Color("bdab81"))
		view.name = "Shield"
		view.rotation.z = PI / 2

func _create_role_tool(node: Node3D, kind: String) -> void:
	if kind in ["lumberjack", "artisan", "guardian", "barbarian"]:
		var handle := BoxMesh.new()
		handle.size = Vector3(0.1, 0.9, 0.1)
		_mesh(node, handle, Vector3(0.48, 0.85, 0), Color("6e4e32"))
		var head := BoxMesh.new()
		head.size = Vector3(0.4, 0.25, 0.18) if kind != "guardian" else Vector3(0.15, 0.9, 0.1)
		_mesh(node, head, Vector3(0.48, 1.25, 0), Color("a7b7b8"))
	elif kind == "hunter":
		var bow := TorusMesh.new()
		bow.inner_radius = 0.28
		bow.outer_radius = 0.35
		var view := _mesh(node, bow, Vector3(0.5, 0.95, 0), Color("9b6c40"))
		view.rotation.x = PI / 2
	elif kind == "mage":
		for index in 2:
			var page := BoxMesh.new()
			page.size = Vector3(0.3, 0.06, 0.4)
			var view := _mesh(node, page, Vector3(0.4 + index * 0.25, 1.0, 0), Color("dad3b5"))
			view.rotation.z = -0.25 if index == 0 else 0.25

func _billboard(id: String, text: String, color: Color) -> Label3D:
	if not _views.has(id):
		var label := Label3D.new()
		label.text = text
		label.modulate = color
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 56
		label.pixel_size = 0.012
		add_child(label)
		_views[id] = label
	return _views[id]

func _sync_survival_views(state: Dictionary, active: Dictionary) -> void:
	for campfire in state.campfires:
		active[campfire.id] = true
		if not _views.has(campfire.id):
			var node := Node3D.new()
			add_child(node)
			node.position = Vector3(campfire.position.x, 0, campfire.position.y)
			for index in 3:
				var log_mesh := BoxMesh.new()
				log_mesh.size = Vector3(0.22, 0.22, 1.3)
				var log_view := _mesh(node, log_mesh, Vector3(0, 0.15, 0), Color("6d4d35"))
				log_view.rotation.y = index * PI / 3
			var flame := SphereMesh.new()
			flame.radius = 0.35
			flame.height = 1.1
			_mesh(node, flame, Vector3(0, 0.65, 0), Color("f6ad4b"))
			_views[campfire.id] = node
	for corpse in state.corpses + state.barbarianCorpses:
		active[corpse.id] = true
		if not _views.has(corpse.id):
			var marker := BoxMesh.new()
			marker.size = Vector3(0.9, 0.2, 0.5)
			_views[corpse.id] = _mesh(self, marker, Vector3(corpse.position.x, 0.1, corpse.position.y), Color("625952"))
	for id in _views:
		var actor_view: Node3D = _views[id]
		if actor_view.has_node("Body"):
			var body: MeshInstance3D = actor_view.get_node("Body")
			body.material_override = _material(COLORS.get(actor_view.get_meta("kind"), Color.WHITE))
			body.position = Vector3(0, body.get_meta("rest_height"), 0)
	for effect in state.effects:
		if effect.kind == "heal-crosses":
			active[effect.id] = true
			var label := _billboard(effect.id, "+", Color("86d17a"))
			label.position = Vector3(effect.position.x, 2.0 + effect.ageSeconds, effect.position.y)
		elif _views.has(effect.targetId) and _views[effect.targetId].has_node("Body"):
			var node: Node3D = _views[effect.targetId]
			var body: MeshInstance3D = node.get_node("Body")
			if effect.kind == "damage-flash":
				body.material_override = _material(Color("fff2df"))
			elif effect.kind == "attack-lunge":
				var direction := Vector3(effect.position.x - node.position.x, 0, effect.position.y - node.position.z).normalized()
				body.position += direction * sin(effect.ageSeconds / effect.durationSeconds * PI) * 0.28
	for alert in state.alerts:
		active[alert.id] = true
		var label := _billboard(alert.id, "!", Color("f1d27a"))
		var point := Vector3(alert.position.x, 0, alert.position.y)
		if _views.has(alert.detectorId):
			point = _views[alert.detectorId].position
		label.position = point + Vector3(0, 2.7, 0)
		if alert.playSound and not _played_alerts.has(alert.id):
			_played_alerts[alert.id] = true
			_alert_player.play()
	for cloud in state.weather.clouds:
		active[cloud.id] = true
		if not _views.has(cloud.id):
			var node := Node3D.new()
			add_child(node)
			for index in 3:
				var puff := SphereMesh.new()
				puff.radius = 2.0 + (0.6 if index == 1 else 0.0)
				puff.height = 2.7
				_mesh(node, puff, Vector3((index - 1) * 2.2, 0, 0), Color("c5d3d7"))
			var rain := Node3D.new()
			rain.name = "Rain"
			node.add_child(rain)
			for index in 16:
				var drop := BoxMesh.new()
				drop.size = Vector3(0.035, 0.75, 0.035)
				_mesh(rain, drop, Vector3((index % 4 - 1.5) * 1.4, -2.0 - floor(index / 4.0) * 1.5, sin(index * 2.4) * 2.0), Color("8dc5df"))
			_views[cloud.id] = node
		_views[cloud.id].position = Vector3(cloud.position.x, 11.0, cloud.position.y)
		_views[cloud.id].get_node("Rain").visible = cloud.phase == "raining"

func _make_alert_sound() -> AudioStreamWAV:
	if _alert_sound != null:
		return _alert_sound
	var samples := PackedByteArray()
	var count := 2646
	samples.resize(count * 2)
	for index in count:
		var time := float(index) / 22050.0
		var envelope := 1.0 - float(index) / count
		samples.encode_s16(index * 2, int(sin(time * TAU * 880) * envelope * 12000))
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
		for child in _views[unit.id].get_children():
			if not child is MeshInstance3D:
				continue
			var local_origin: Vector3 = child.to_local(origin)
			var local_direction: Vector3 = child.global_basis.inverse() * direction
			var hit: Variant = child.get_aabb().intersects_ray(local_origin, local_direction)
			if hit is Vector3:
				var distance: float = origin.distance_squared_to(child.to_global(hit))
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
	var node := Node3D.new()
	node.position = Vector3(resource.position.x, 0, resource.position.y)
	add_child(node)
	if resource.source == "tree":
		var trunk := CylinderMesh.new()
		trunk.top_radius = 0.2
		trunk.bottom_radius = 0.3
		trunk.height = 2.0
		_mesh(node, trunk, Vector3(0, 1, 0), Color("76563c"))
		var canopy := SphereMesh.new()
		canopy.radius = 1.1
		canopy.height = 2.0
		_mesh(node, canopy, Vector3(0, 2.3, 0), COLORS.wood)
	elif resource.source == "twigs":
		for index in 3:
			var twig := BoxMesh.new()
			twig.size = Vector3(0.12, 0.12, 0.8)
			var view := _mesh(node, twig, Vector3((index - 1) * 0.18, 0.1, 0), COLORS.twigs)
			view.rotation.y = index * 1.1
	elif resource.type == "stone":
		for index in 3:
			var stone := BoxMesh.new()
			stone.size = Vector3(0.65, 0.65 + index * 0.15, 0.6)
			_mesh(node, stone, Vector3((index - 1) * 0.45, stone.size.y / 2.0, index * 0.18), COLORS.stone)
	elif resource.type == "spark":
		var crystal := CylinderMesh.new()
		crystal.top_radius = 0
		crystal.bottom_radius = 0.55
		crystal.height = 1.4
		crystal.radial_segments = 4
		_mesh(node, crystal, Vector3(0, 0.7, 0), COLORS.spark)
	else:
		var bush := SphereMesh.new()
		bush.radius = 0.8
		bush.height = 1.1
		_mesh(node, bush, Vector3(0, 0.55, 0), COLORS.food)
	return node

func _mesh(parent: Node3D, shape: Mesh, offset: Vector3, color: Color) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = shape
	view.position = offset
	view.material_override = _material(color)
	parent.add_child(view)
	return view

func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		_materials[color] = material
	return _materials[color]
