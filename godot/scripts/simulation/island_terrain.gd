extends RefCounted
## Saved rows describe immutable topology. The graph is derived from them on demand.
const SIZE := 105
const TILE := 1.5
const ORIGIN := 2.0
const DIRS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
const SEA := 46 # .
const LOW := 49 # 1
const HIGH := 50 # 2
const SUMMIT := 51
const UPPER_EAST := 69
const UPPER_WEST := 87
const EAST := 62 # > ascending east
const WEST := 60 # < ascending west
static var _graphs: Array = []
static var _meadows: Array = []

static func cell(p: Dictionary) -> Vector2i:
	return Vector2i(((Vector2(p.x, p.y) - Vector2.ONE * ORIGIN) / TILE).round())

static func center(c: Vector2i) -> Dictionary:
	return {"x": ORIGIN + TILE * c.x, "y": ORIGIN + TILE * c.y}

static func code(rows: Array, c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.y >= rows.size() or c.x >= SIZE:
		return SEA
	return rows[c.y].unicode_at(c.x)

static func ramp(k: int) -> bool:
	return k in [EAST, WEST, UPPER_EAST, UPPER_WEST]

static func level(k: int) -> int:
	if k == SEA: return 0
	if k == SUMMIT: return 3
	return 2 if k in [HIGH, UPPER_EAST, UPPER_WEST] else 1

static func east(k: int) -> bool:
	return k in [EAST, UPPER_EAST]

static func edge(rows: Array, a: Vector2i, b: Vector2i) -> bool:
	var first := code(rows, a)
	var second := code(rows, b)
	if first == SEA or second == SEA:
		return false
	if first == second:
		return true
	var dir := b - a
	if ramp(first):
		var uphill := Vector2i.RIGHT if east(first) else Vector2i.LEFT
		return not ramp(second) and ((dir == uphill and level(second) == level(first)+1) or (dir == -uphill and level(second) == level(first)))
	if ramp(second):
		return edge(rows, b, a)
	return false

static func fraction(rows: Array, p: Dictionary) -> float:
	var c := cell(p)
	var k := code(rows, c)
	if ramp(k):
		return level(k)-1 + clampf(0.5 + (float(p.x) - float(center(c).x)) / TILE * (1 if east(k) else -1), 0, 1)
	return maxf(0,level(k)-1)

static func fits(rows: Array, p: Dictionary, radius: float = 0.32, placement: bool = false) -> bool:
	if rows.is_empty():
		return true
	var c := cell(p)
	var kind := code(rows, c)
	if kind == SEA or (placement and ramp(kind)):
		return false
	if placement and (ramp(code(rows,c+Vector2i.LEFT)) or ramp(code(rows,c+Vector2i.RIGHT))):
		return false
	var point := Vector2(p.x, p.y)
	for dx in [-radius, radius]:
		for dy in [-radius, radius]:
			var other := cell({"x": point.x + dx, "y": point.y + dy})
			if other == c:
				continue
			if placement and code(rows, other) != kind:
				return false
			if not _cross(rows, c, other):
				return false
	return true

static func _cross(rows: Array, a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return code(rows, a) != SEA
	if a.x != b.x and a.y != b.y:
		var horizontal := Vector2i(b.x, a.y)
		var vertical := Vector2i(a.x, b.y)
		return edge(rows, a, horizontal) and edge(rows, horizontal, b) and edge(rows, a, vertical) and edge(rows, vertical, b)
	return edge(rows, a, b)

static func clear(rows: Array, a: Dictionary, b: Dictionary, radius: float = 0.32) -> bool:
	if rows.is_empty():
		return true
	var start := Vector2(a.x, a.y)
	var end := Vector2(b.x, b.y)
	var steps := maxi(1, ceili(start.distance_to(end) / 0.3))
	var previous := cell(a)
	for i in range(1, steps + 1):
		var v := start.lerp(end, float(i) / steps)
		var p := {"x": v.x, "y": v.y}
		var c := cell(p)
		if not _cross(rows, previous, c) or not fits(rows, p, radius):
			return false
		previous = c
	return true

static func graph(rows: Array) -> AStar2D:
	for entry in _graphs:
		if is_same(rows,entry.rows):
			return entry.graph
	var grid := AStar2D.new()
	_graphs.append({"rows":rows,"graph":grid})
	if _graphs.size() > 12:
		_graphs.pop_front()
	for y in rows.size():
		for x in SIZE:
			var c := Vector2i(x,y)
			if code(rows,c) == SEA:
				continue
			var id := y * SIZE + x
			grid.add_point(id, Vector2(c))
			for dir: Vector2i in [Vector2i.UP, Vector2i.LEFT]:
				var n := c + dir
				if edge(rows,c,n):
					grid.connect_points(id,n.y * SIZE + n.x)
	return grid

static func nearest(rows: Array, p: Dictionary, radius: float = 0.32, placement: bool = false) -> Dictionary:
	if fits(rows, p, radius, placement):
		return p
	var origin := cell(p)
	var best := {}
	var distance := INF
	for ring in range(0, SIZE + 1):
		for x in range(-ring, ring + 1):
			var offsets := range(-ring, ring + 1) if absi(x) == ring else [-ring, ring]
			for y: int in offsets:
				var test := center(origin + Vector2i(x,y))
				var d := Vector2(test.x - p.x, test.y - p.y).length_squared()
				if d < distance and fits(rows,test,radius,placement):
					best = test
					distance = d
		if distance < pow((ring + 0.5) * TILE, 2):
			break
	return best

## Choose a visible waypoint on the A* corridor. Cache per agent, never in the map.
## Leave steering clearance between samples when smoothing across cell corners.
static func waypoint(rows: Array, start: Dictionary, goal: Dictionary, memory: Dictionary) -> Dictionary:
	if clear(rows,start,goal,0.48):
		memory.erase("terrainRoute")
		return goal
	var a := cell(start)
	var b := cell(goal)
	var end_id := b.y * SIZE + b.x
	var route: Array = memory.get("terrainRoute", [])
	if route.is_empty() or int(route.back()) != end_id:
		var g := graph(rows)
		var start_id := a.y * SIZE + a.x
		if not g.has_point(start_id) or not g.has_point(end_id):
			return start
		route = Array(g.get_id_path(start_id,end_id))
		memory.terrainRoute = route
	while route.size() > 1:
		var next := int(route[1])
		var point := center(Vector2i(next % SIZE, floori(float(next) / SIZE)))
		if not clear(rows,start,point,0.48):
			break
		route.pop_front()
	if route.is_empty():
		return start
	var id := int(route[0])
	var result := center(Vector2i(id % SIZE, floori(float(id) / SIZE)))
	if not clear(rows,start,result):
		memory.erase("terrainRoute")
		return start
	return result

static func meadow_rows(region: Dictionary, terrain: Array) -> Array:
	for entry in _meadows:
		if is_same(entry.cells,region.cells) and is_same(entry.terrain,terrain):
			return entry.rows
	var mask := []
	mask.resize(SIZE)
	mask.fill(".".repeat(SIZE))
	var origin := cell(region)
	for local in region.cells:
		var c := origin + Vector2i(local.x,local.y)
		if not ramp(code(terrain,c)):
			mask[c.y][c.x] = "1"
	_meadows.append({"cells":region.cells,"terrain":terrain,"rows":mask})
	if _meadows.size() > 12:
		_meadows.pop_front()
	return mask
