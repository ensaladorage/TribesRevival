@tool
extends "res://scripts/view/world_element.gd"
## Slots use the source layout: west/interior/east/both, then north/interior/south/both.

const Footprint = preload("res://scripts/simulation/biome_footprint.gd")
@export var ground_tiles: Array[AtlasTexture]:
	set(value):
		if Engine.is_editor_hint():
			for tile in ground_tiles:
				if tile != null and tile.changed.is_connected(_preview):
					tile.changed.disconnect(_preview)
		ground_tiles = value
		if Engine.is_editor_hint():
			for tile in ground_tiles:
				if tile != null and not tile.changed.is_connected(_preview):
					tile.changed.connect(_preview)
			if is_node_ready():
				_preview()

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		_preview()

func _preview() -> void:
	if not is_inside_tree():
		return
	set_cells([{"x": 0, "y": -1}, {"x": -1, "y": 0}, {"x": 0, "y": 0},
		{"x": 1, "y": 0}, {"x": 0, "y": 1}, {"x": 1, "y": 1}])

static func _axis_index(low: bool, high: bool) -> int:
	if low and high:
		return 3
	if low:
		return 0
	if high:
		return 2
	return 1

func set_cells(cells: Array) -> void:
	if ground_tiles.size() != 16 or ground_tiles.any(func(tile): return tile == null or tile.atlas == null):
		$Visual/Default/Patch.mesh = null
		return
	var occupied := {}
	for cell in cells:
		occupied[Vector2i(cell.x, cell.y)] = true
	var surfaces := {}
	for coord: Vector2i in occupied:
		var column := _axis_index(not occupied.has(coord + Vector2i.LEFT), not occupied.has(coord + Vector2i.RIGHT))
		var row := _axis_index(not occupied.has(coord + Vector2i.UP), not occupied.has(coord + Vector2i.DOWN))
		var tile := ground_tiles[row * 4 + column]
		if not surfaces.has(tile.atlas):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var material := StandardMaterial3D.new()
			material.albedo_texture = tile.atlas
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.metallic_specular = 0.0
			surface.set_material(material)
			surfaces[tile.atlas] = surface
		_add_tile(surfaces[tile.atlas], coord, tile)
	var ground := ArrayMesh.new()
	for surface: SurfaceTool in surfaces.values():
		surface.index()
		surface.commit(ground)
	$Visual/Default/Patch.mesh = ground

static func _add_tile(surface: SurfaceTool, coord: Vector2i, tile: AtlasTexture) -> void:
	var rect := tile.region.grow(-0.5)
	for uv: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.ZERO, Vector2.ONE, Vector2.DOWN]:
		var point := (Vector2(coord) + uv - Vector2.ONE * 0.5) * Footprint.TILE_SIZE
		surface.set_uv((rect.position + rect.size * uv) / tile.atlas.get_size())
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(point.x, 0, point.y))
