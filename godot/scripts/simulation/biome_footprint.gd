extends RefCounted
## Local tile coordinates are stored as plain numbers so JSON round-trips losslessly.

const Random = preload("res://scripts/simulation/seeded_random.gd")
const TILE_SIZE := 1.5
const JITTER := TILE_SIZE * 0.24
const START := Vector2(80, 80)

static func create(radius: float, seed_text: String) -> Array:
	var random := Random.new(seed_text)
	# Vary the contour smoothly around the core so neighbouring edge tiles form lobes.
	var elongation := random.next_float(0.0, TAU)
	var lobes := random.next_float(0.0, TAU)
	var bias := random.next_float(0.0, TAU)
	var cells: Array = [{"x": 0, "y": 0}]
	var visited := {Vector2i.ZERO: true}
	var cursor := 0
	while cursor < cells.size():
		var current := Vector2i(cells[cursor].x, cells[cursor].y)
		cursor += 1
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN]:
			var next := current + direction
			if visited.has(next):
				continue
			visited[next] = true
			var far_corner := (Vector2(next.abs()) + Vector2.ONE * 0.5) * TILE_SIZE
			if far_corner.length() > radius:
				continue
			var angle := Vector2(next).angle()
			var reach := 0.76 + 0.17 * cos(2.0 * angle + elongation) + 0.14 * cos(3.0 * angle + lobes) + 0.09 * cos(angle + bias)
			if Vector2(next).length() * TILE_SIZE > radius * reach:
				continue
			cells.append({"x": next.x, "y": next.y})
	return cells

## A straight patrol segment between any two points in this disk stays on grass.
static func inscribed_radius(region: Dictionary) -> float:
	var occupied := {}
	for cell in region.cells:
		occupied[Vector2i(cell.x, cell.y)] = true
	var nearest := INF
	for coord: Vector2i in occupied:
		for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var neighbour := coord + direction
			if not occupied.has(neighbour):
				var distance := (Vector2(neighbour.abs()) - Vector2.ONE * 0.5).max(Vector2.ZERO)
				nearest = minf(nearest, distance.length() * TILE_SIZE)
	return nearest

static func center(region: Dictionary, cell: Dictionary) -> Vector2:
	return Vector2(region.x, region.y) + Vector2(cell.x, cell.y) * TILE_SIZE

static func contains(region: Dictionary, point: Vector2) -> bool:
	var local := Vector2i(((point - Vector2(region.x, region.y)) / TILE_SIZE).round())
	return region.cells.any(func(cell): return int(cell.x) == local.x and int(cell.y) == local.y)

static func eligible(region: Dictionary, exclusion: float) -> Array:
	if exclusion <= 0:
		return region.get("spawnCells",region.cells)
	# The full sampling square must lie outside the starting exclusion.
	return region.get("spawnCells",region.cells).filter(func(cell): return center(region, cell).distance_to(START) >= exclusion + sqrt(2.0) * JITTER + 0.01)

static func sample(region: Dictionary, random: Random, cells: Array) -> Dictionary:
	var point := center(region, cells[random.next_int(0, cells.size() - 1)])
	point += Vector2(random.next_float(-JITTER, JITTER), random.next_float(-JITTER, JITTER))
	return {"x": snappedf(point.x, 0.01), "y": snappedf(point.y, 0.01)}
