extends Camera3D
## Camera/pointer projection only. Logical world bounds are owned by State.

const BASE_VIEW_HEIGHT := 72.0
const CAMERA_DISTANCE := 120.0
const TerrainView = preload("res://scripts/view/terrain_projection.gd")
const T = TerrainView.T
var terrain: Array = []
const YAW := 0.0
const PITCH := TerrainView.PITCH
const EDGE_MARGIN := 72.0
const EDGE_SCROLL_SPEED := 32.0
const RECENTER_SPEED := 4.5

var focus := Vector3(80, 0, 80 * TerrainView.DEPTH_SCALE)
var zoom := 0.5
var zoom_min := 0.5
var zoom_max := 1.0
var recentering := false

func _ready() -> void:
	projection = Camera3D.PROJECTION_ORTHOGONAL
	keep_aspect = Camera3D.KEEP_HEIGHT
	apply_transform()

func adjust_zoom(amount: float) -> void:
	zoom = clampf(zoom + amount, zoom_min, zoom_max)
	size = BASE_VIEW_HEIGHT * zoom

func ground_point(screen_point: Vector2) -> Variant:
	var origin := project_ray_origin(screen_point)
	var direction := project_ray_normal(screen_point)
	var low: Vector3 = Plane(Vector3.UP,0).intersects_ray(origin,direction)
	var high: Vector3 = Plane(Vector3.UP,TerrainView.RISE).intersects_ray(origin,direction)
	var summit: Vector3 = Plane(Vector3.UP,2 * TerrainView.RISE).intersects_ray(origin,direction)
	for sample in [summit,high,low]:
		var p := TerrainView.logical(sample)
		var height := TerrainView.RISE * T.fraction(terrain,p)
		var hit: Vector3 = Plane(Vector3.UP,height).intersects_ray(origin,direction)
		var actual := TerrainView.logical(hit)
		if T.cell(actual) == T.cell(p) and T.code(terrain,T.cell(p)) != T.SEA:
			return hit
	low.y = -1.0
	return low

func advance(seconds: float, dragging: bool, totem_position: Dictionary) -> void:
	if dragging:
		_scroll_at_edge(seconds)
	elif recentering:
		var target := TerrainView.world(totem_position,terrain)
		focus = focus.lerp(target, minf(seconds * RECENTER_SPEED, 1.0))
		if focus.distance_squared_to(target) < 0.01:
			focus = target
			recentering = false
	apply_transform()

func apply_transform() -> void:
	var horizontal := CAMERA_DISTANCE * cos(PITCH)
	position = focus + Vector3(sin(YAW) * horizontal, CAMERA_DISTANCE * sin(PITCH), cos(YAW) * horizontal)
	look_at(focus)
	size = BASE_VIEW_HEIGHT * zoom

func _scroll_at_edge(seconds: float) -> void:
	var pointer := get_viewport().get_mouse_position()
	var viewport_size := get_viewport().get_visible_rect().size
	var horizontal := 0.0
	var vertical := 0.0
	if pointer.x < EDGE_MARGIN:
		horizontal = -(1.0 - pointer.x / EDGE_MARGIN)
	elif pointer.x > viewport_size.x - EDGE_MARGIN:
		horizontal = 1.0 - (viewport_size.x - pointer.x) / EDGE_MARGIN
	if pointer.y < EDGE_MARGIN:
		vertical = 1.0 - pointer.y / EDGE_MARGIN
	elif pointer.y > viewport_size.y - EDGE_MARGIN:
		vertical = -(1.0 - (viewport_size.y - pointer.y) / EDGE_MARGIN)
	var right := global_basis.x
	right.y = 0
	var up := global_basis.y
	up.y = 0
	var movement := right.normalized() * horizontal + up.normalized() * vertical
	if movement.length_squared() > 0:
		focus += movement.normalized() * EDGE_SCROLL_SPEED * seconds
		focus.x = clampf(focus.x, 0, 160)
		focus.z = clampf(focus.z, 0, 160 * TerrainView.DEPTH_SCALE)
