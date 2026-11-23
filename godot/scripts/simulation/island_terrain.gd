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

static func same_level(rows: Array, first: Dictionary, second: Dictionary) -> bool:
	return level(code(rows, cell(first))) == level(code(rows, cell(second)))

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

# A step shorter than a tile can enter a uniform land cell from any neighbour.
# Cache this property because the terrain rows are immutable for a saved world.
static var _uniform_worlds: Array = []

static func _uniform_cache(rows: Array) -> Dictionary:
	for world in _uniform_worlds:
		if is_same(world.rows, rows):
			return world.cells
	var cells := {}
	_uniform_worlds.append({"rows":rows,"cells":cells})
	if _uniform_worlds.size() > 4:
		_uniform_worlds.pop_front()
	return cells

static func _uniform_land(rows: Array, c: Vector2i) -> bool:
	var kind := code(rows,c)
	if kind == SEA or ramp(kind):
		return false
	for y in range(c.y-1,c.y+2):
		for x in range(c.x-1,c.x+2):
			if code(rows,Vector2i(x,y)) != kind:
				return false
	return true

static func clear(rows: Array, a: Dictionary, b: Dictionary, radius: float = 0.32) -> bool:
	if rows.is_empty():
		return true
	var start := Vector2(a.x, a.y)
	var end := Vector2(b.x, b.y)
	var steps := maxi(1, ceili(start.distance_to(end) / 0.3))
	var previous := cell(a)
	var uniform := _uniform_cache(rows)
	for i in range(1, steps + 1):
		var v := start.lerp(end, float(i) / steps)
		var c := Vector2i(((v - Vector2.ONE * ORIGIN) / TILE).round())
		if radius <= TILE * 0.5:
			if not uniform.has(c):
				uniform[c] = _uniform_land(rows,c)
			if uniform[c]:
				previous = c
				continue
		if not _cross(rows, previous, c) or not fits(rows, {"x":v.x,"y":v.y}, radius):
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

# Components use the same edge rules as pathfinding. Stair cells belong
# to the full walking graph but never connect separate flat surfaces.
static var _surface_cache: Array = []

static func surface_ids(rows: Array, flat_only: bool) -> Dictionary:
	for entry in _surface_cache:
		if is_same(entry.rows, rows) and entry.flat == flat_only:
			return entry.ids
	var ids := {}
	for y in rows.size():
		for x in SIZE:
			var origin := Vector2i(x,y)
			var kind := code(rows,origin)
			if ids.has(origin) or kind == SEA or (flat_only and ramp(kind)):
				continue
			var queue: Array[Vector2i] = [origin]
			ids[origin] = origin
			var head := 0
			while head < queue.size():
				var current := queue[head]
				head += 1
				for direction: Vector2i in DIRS:
					var adjacent := current + direction
					if ids.has(adjacent) or (flat_only and code(rows,adjacent) != kind):
						continue
					if edge(rows,current,adjacent):
						ids[adjacent] = origin
						queue.append(adjacent)
	_surface_cache.append({"rows":rows,"flat":flat_only,"ids":ids})
	if _surface_cache.size() > 12:
		_surface_cache.pop_front()
	return ids

static func route_length(rows: Array, start: Dictionary, goal: Dictionary) -> float:
	var origin := Vector2(start.x, start.y)
	var end := Vector2(goal.x, goal.y)
	if clear(rows, start, goal):
		return origin.distance_to(end)
	var grid := graph(rows)
	var a := cell(start)
	var b := cell(goal)
	var first := a.y * SIZE + a.x
	var last := b.y * SIZE + b.x
	if not grid.has_point(first) or not grid.has_point(last) or not fits(rows, goal):
		return INF
	var path := grid.get_id_path(first, last)
	if path.is_empty():
		return INF
	return origin.distance_to(Vector2(a) * TILE + Vector2.ONE * ORIGIN) + (path.size()-1) * TILE + end.distance_to(Vector2(b) * TILE + Vector2.ONE * ORIGIN)

const DROP_REACH := 0.65

static func drop_position(rows: Array, origin: Dictionary, point: Dictionary) -> Dictionary:
	if _inside_walk_bounds(point) and fits(rows, point):
		return point
	return work_position(rows, origin, {"position": point, "interactionRadius": DROP_REACH}, true)

static func valid_drop_position(rows: Array, approach: Dictionary, point: Dictionary) -> bool:
	return _inside_walk_bounds(approach) and fits(rows, approach) and Vector2(approach.x - point.x, approach.y - point.y).length() <= DROP_REACH + 1e-6 and clear(rows, approach, point, 0.0)

static func _inside_walk_bounds(point: Dictionary) -> bool:
	var limit := ORIGIN + (SIZE - 1) * TILE
	return point.x >= ORIGIN and point.x <= limit and point.y >= ORIGIN and point.y <= limit

static func work_position(rows: Array, origin: Dictionary, target: Dictionary, bounded: bool = false) -> Dictionary:
	var point: Dictionary = target.position
	if not target.has("interactionRadius"):
		return point
	var radius := maxf(target.interactionRadius, 0.1)
	var direction := Vector2(origin.x-point.x, origin.y-point.y).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var best := {}
	var shortest := INF
	for i in 8:
		var offset := direction.rotated(i * TAU / 8) * radius
		var candidate := {"x":point.x+offset.x,"y":point.y+offset.y}
		if bounded:
			var limit := ORIGIN + (SIZE - 1) * TILE
			candidate.x = clampf(candidate.x, ORIGIN, limit)
			candidate.y = clampf(candidate.y, ORIGIN, limit)
		if bounded and not valid_drop_position(rows, candidate, point):
			continue
		if not bounded and (not fits(rows,candidate) or not clear(rows,candidate,point,0.0)):
			continue
		if i == 0 and clear(rows,origin,candidate):
			return candidate
		var cost := route_length(rows,origin,candidate)
		if cost < shortest:
			best = candidate
			shortest = cost
	return best

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
static func waypoint(rows: Array, start: Dictionary, goal: Dictionary, memory: Dictionary, allow_tight_goal: bool = false) -> Dictionary:
	# Drop pickups can use normal walking clearance for the final step inside a tile.
	# Keep the wider clearance while smoothing routes across tile boundaries.
	if clear(rows,start,goal,0.48) or (allow_tight_goal and cell(start) == cell(goal) and clear(rows,start,goal)):
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

## Approach tickets last only while an actor is actively heading for this stair.
static func stair_waypoint(state: Dictionary, actor: Dictionary, goal: Dictionary) -> Dictionary:
	var rows: Array = state.get("terrain", [])
	if rows.is_empty():
		return goal
	var pos: Dictionary = actor.position
	var start := Vector2(pos.x, pos.y)
	var delta := Vector2(goal.x, goal.y) - start
	var stairs := Vector2i(-1,-1)
	for i in range(1 + ceili(minf(delta.length(), TILE * 2.5) / 0.35)):
		var sample := start + delta.limit_length(i * 0.35)
		var c := cell({"x":sample.x,"y":sample.y})
		if ramp(code(rows,c)):
			stairs = c
			break
	if stairs.x < 0:
		actor.erase("stairTicket")
		return goal
	var key := stairs.y * SIZE + stairs.x
	var ticket: Dictionary = actor.get("stairTicket", {})
	if ticket.get("key",-1) != key or ticket.get("seen",-2) < state.tick - 1:
		ticket = {"key":key,"arrival":state.tick}
		actor.stairTicket = ticket
	ticket.seen = state.tick
	if absf(delta.x) > 0.01:
		ticket.exitDirection = int(signf(delta.x))
	if cell(pos) == stairs:
		return goal
	for other in state.units + state.barbarians:
		if other.id == actor.id or other.get("isCarried",false) or not other.get("isAlive",true):
			continue
		var theirs: Dictionary = other.get("stairTicket",{})
		var ahead: bool = theirs.get("key",-1) == key and theirs.get("seen",-2) >= state.tick-1 and (theirs.arrival < ticket.arrival or (theirs.arrival == ticket.arrival and other.id < actor.id))
		if not ahead and cell(other.position) != stairs:
			continue
		var landing := stairs + Vector2i.LEFT if pos.x < center(stairs).x else stairs + Vector2i.RIGHT
		for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, landing-stairs]:
			var bay := center(landing + offset)
			if clear(rows,pos,bay):
				return bay
		return pos
	return goal

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
