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

func setup(state: Dictionary) -> void:
	for child in get_children():
		child.free()
	_views.clear()
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
		_mesh(node, body, Vector3(0, body.height / 2.0, 0), COLORS.get(kind, Color.WHITE))
		_views[actor.id] = node
	var previous: Dictionary = _previous_positions.get(actor.id, actor.position)
	_views[actor.id].position = Vector3(lerpf(previous.x, actor.position.x, _alpha), 0, lerpf(previous.y, actor.position.y, _alpha))

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
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1.0
		_materials[color] = material
	view.material_override = _materials[color]
	parent.add_child(view)
	return view
