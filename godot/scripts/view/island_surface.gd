extends MeshInstance3D
const P = preload("res://scripts/view/terrain_projection.gd")
const T = P.T
const AT := "res://assets/biomes/Tileset/"
@export var palettes := {
	"clearing": preload(AT+"Tilemap Claro.png"), "meadow": preload(AT+"Tilemap Pradera.png"),
	"forest": preload(AT+"Tilemap_Bosque.png"), "ruins": preload(AT+"Tilemap Ruinas.png"),
	"mountain": preload(AT+"Tilemap montañas.png"), "rocky": preload(AT+"Tilemap_Pegregal.png")}
@export_range(3, 24) var biome_edge_pixels: int = 12
@export var cliff: Texture2D = preload(AT+"Tilemap_Pegregal.png")
@export var shadow: Texture2D = preload(AT+"Shadow.png")
@export var foam: Texture2D = preload(AT+"Water Foam.png")
var _batches := {}
var _fringes := {}
var _foam_material := ShaderMaterial.new()

func build(state: Dictionary) -> void:
	var rows: Array = state.terrain
	var layers: Array[Dictionary] = [{},{},{}]
	for biome in state.biomes:
		var origin := T.cell(biome.region)
		for local in biome.region.cells:
			var c := origin + Vector2i(local.x,local.y)
			layers[T.level(T.code(rows,c))-1][c] = biome.id
		for local in biome.region.get("covered",[]):
			layers[int(biome.level)-1][origin + Vector2i(local.x,local.y)] = biome.id
	_foam_material.shader = preload("res://shaders/coastal_foam.gdshader")
	_foam_material.set_shader_parameter("frames",foam)
	var shore := layers[0].duplicate()
	shore.merge(layers[1])
	for c: Vector2i in shore:
		if T.DIRS.all(func(d): return shore.has(c+d)): continue
		var point := T.center(c)
		var phase := posmod(("%s:%d:%d" % [state.seed,c.x,c.y]).hash(),16)
		_quad(foam,Rect2(0,0,192,192),point.x-1.5*T.TILE,point.y-1.5*T.TILE,3,3,0.005,0.005,phase)
	for layer in layers.size():
		var owners := layers[layer]
		var top := layer * P.RISE
		for c: Vector2i in owners:
			var k := T.code(rows,c)
			var palette: Texture2D = palettes[owners[c]]
			var exposed := []
			for dir in T.DIRS:
				var n: Vector2i = c + dir
				var neighbour := T.code(rows,n)
				var joined := T.ramp(neighbour) and T.level(neighbour) == layer and T.edge(rows,c,n)
				exposed.append(not owners.has(n) and not joined)
			var col := _axis(exposed[0],exposed[1])
			var row := _axis(exposed[2],exposed[3])
			var point := T.center(c)
			var x: float = point.x - T.TILE/2
			var z: float = point.y - T.TILE/2
			if layer > 0:
				_quad(shadow,Rect2(0,0,192,192),x-T.TILE,z-T.TILE,3,3,top-P.RISE+0.05,top-P.RISE+0.05)
			var block := 5 if layer > 0 and palette != cliff else 0
			var tile_y := 256 if palette == cliff and row == 3 else row*64
			_quad(palette,Rect2((block+col)*64,tile_y,64,64),x,z,1,1,top+0.03,top+0.03)
			for side in T.DIRS.size():
				var other: String = owners.get(c+T.DIRS[side],"")
				if other <= owners[c] or palette == cliff or palettes[other] == cliff: continue
				_quad(palettes[other],Rect2(384 if layer else 64,64,64,64),x,z,1,1,top+0.034,top+0.034,0,side)
			if T.ramp(k) and T.level(k) == layer+1:
				var east := T.east(k)
				var upper: Vector2i = c + (Vector2i.RIGHT if east else Vector2i.LEFT)
				var grass: Texture2D = palettes[layers[layer+1][upper]]
				if grass == cliff: grass = palette if palette != cliff else palettes.mountain
				_stair(grass,Rect2(0 if east else 192,256,64,128),x,z,east,T.code(rows,c+Vector2i.DOWN) != k,top)
			if layer > 0 and exposed[3]:
				# The vertical face ends at the southern edge of this footprint.
				var below := layers[layer-1]
				var wet := not below.has(c) and not below.has(c+Vector2i.DOWN)
				var face_y := 320 if wet else (192 if palette == cliff else 256)
				var wall := palettes.mountain as Texture2D if wet and palette == cliff else palette
				var face_block := 5 if wall != cliff else 0
				_quad(wall,Rect2((face_block+col)*64,face_y,64,64),x,z+T.TILE,1,0,top+0.03,top-P.RISE+0.03)
	var combined := ArrayMesh.new()
	for batch: SurfaceTool in _batches.values():
		batch.index()
		batch.commit(combined)
	mesh = combined
	_batches.clear()

func _axis(first: bool, last: bool) -> int:
	if first: return 3 if last else 0
	return 2 if last else 1

## Map the two-tile-tall painted silhouette onto the walkable east/west slope.
## At the southern edge the remaining triangle covers the exposed rock face.
func _stair(tex: Texture2D, region: Rect2, x: float, z: float, east: bool, exposed_south: bool, base_height: float) -> void:
	var batch := _batch(tex, -1)
	for face in (2 if exposed_south else 1):
		for corner: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.ZERO,Vector2.ONE,Vector2.DOWN]:
			var rise := corner.x if east else 1.0 - corner.x
			var depth := corner.y
			if face == 1:
				depth = 1.0
				rise *= 1.0 - corner.y
			var image_uv := Vector2(corner.x, (depth + 1.0 - rise) * 0.5)
			var rect := region.grow(-0.5)
			batch.set_uv((rect.position + image_uv * rect.size) / tex.get_size())
			batch.set_color(Color(0, 0, 1, 1))
			batch.set_normal(Vector3.UP)
			batch.add_vertex(Vector3(x+corner.x*T.TILE, base_height+0.035+rise*P.RISE, (z+depth*T.TILE)*P.DEPTH_SCALE))

func _batch(tex: Texture2D, fringe: int) -> SurfaceTool:
	var key: Resource = tex
	if fringe >= 0:
		if not _fringes.has(tex):
			var edge_material := ShaderMaterial.new()
			edge_material.shader = preload("res://shaders/biome_grass_edge.gdshader")
			edge_material.set_shader_parameter("grass",tex)
			edge_material.set_shader_parameter("width_pixels",biome_edge_pixels)
			_fringes[tex] = edge_material
		key = _fringes[tex]
	if not _batches.has(key):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if tex == shadow else BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_texture = tex
		tool.set_material(key if fringe >= 0 else (_foam_material if tex == foam else mat))
		_batches[key] = tool
	return _batches[key]

func _quad(tex: Texture2D, region: Rect2, x: float, z: float, width: int, depth: int, north: float, south: float, phase: int = 0, fringe: int = -1) -> void:
	var batch := _batch(tex, fringe)
	var uv_rect := region.grow(-0.5)
	var size := Vector2(192,192) if tex == foam else tex.get_size()
	for uv: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.ZERO,Vector2.ONE,Vector2.DOWN]:
		batch.set_uv((uv_rect.position + uv * uv_rect.size) / size)
		batch.set_color(Color(phase / 15.0,maxi(0,fringe) / 3.0,1,1))
		batch.set_normal(Vector3.UP)
		batch.add_vertex(Vector3(x+uv.x*width*T.TILE,lerpf(north,south,uv.y),(z+uv.y*depth*T.TILE)*P.DEPTH_SCALE))
