extends RefCounted

const T = preload("res://scripts/simulation/island_terrain.gd")
const Random = preload("res://scripts/simulation/seeded_random.gd")
const START := Vector2i(52,52)
const FALLBACK_SEED := "terrain-reserve-0"
const LOW_TYPES := ["meadow","forest","forest","meadow","forest"]
const HIGH_TYPES := ["rocky","ruins","forest","meadow","forest"]

static func generate(seed_text: String) -> Dictionary:
	for attempt in 9:
		var layout_seed := FALLBACK_SEED if attempt == 8 else "%s:islands:%d" % [seed_text,attempt]
		var layout := _layout(Random.new(layout_seed))
		if not layout.is_empty():
			return layout
	push_error("Invalid island fallback")
	return {}

static func _landform(land: Dictionary, origin: Vector2i, rx: int, ry: int, notch: int, kind: int) -> void:
	for x in range(-rx, rx + 1):
		for y in range(-ry, ry + 1):
			if absi(x) >= rx - notch + 1 and absi(y) >= ry - notch + 1:
				continue
			land[origin + Vector2i(x,y)] = kind

static func _link_cell(start: Vector2i, end: Vector2i, progress: float) -> Vector2i:
	var bend := Vector2i(end.x, start.y) if absi(end.x-start.x) >= absi(end.y-start.y) else Vector2i(start.x,end.y)
	var first := Vector2(start).distance_to(Vector2(bend))
	var second := Vector2(bend).distance_to(Vector2(end))
	var distance := progress * (first + second)
	if distance <= first:
		return Vector2i(Vector2(start).move_toward(Vector2(bend),distance).round())
	return Vector2i(Vector2(bend).move_toward(Vector2(end),distance-first).round())

static func _layout(rng: Random) -> Dictionary:
	var land := {}
	var centers: Array[Vector2i] = [START]
	var kinds: Array[String] = ["clearing"]
	var levels: Array[int] = [1]
	_landform(land,START,11,10,2,T.LOW)
	var anchors: Array[Vector2i] = []
	var links: Array[Vector2i] = []
	var phase := rng.next_float(0,TAU)
	for i in 5:
		var direction := Vector2.from_angle(phase + TAU * i / 5 + rng.next_float(-0.14,0.14))
		var distance := rng.next_int(23,34)
		var anchor := START + Vector2i((direction * distance).round())
		anchors.append(anchor)
		var link := START
		if i in [1,3]:
			link = anchors[i-1]
		links.append(link)
		# Broad cardinal paths leave straight banks even at the turn.
		for j in range(101):
			var c := _link_cell(link,anchor,j / 100.0)
			for x in range(-2,3):
				for y in range(-2,3):
					land[c + Vector2i(x,y)] = T.LOW
	var base := land.duplicate()
	for i in anchors.size():
		var anchor := anchors[i]
		var side := 1 if anchor.x >= START.x else -1
		_landform(base,anchor,rng.next_int(9,12),rng.next_int(7,9),rng.next_int(1,2),T.LOW)
		for c in base:
			if not land.has(c): land[c] = T.LOW
		var upper := anchor + Vector2i(side * (3 if i in [1,3] else 6),0)
		var radius := 5
		_landform(land,upper,radius,4,rng.next_int(0,1),T.HIGH)
		centers.append(anchor - Vector2i(side * 6,2))
		kinds.append(LOW_TYPES[i])
		levels.append(1)
		centers.append(upper)
		kinds.append(HIGH_TYPES[i])
		levels.append(2)
		# Two adjacent stair lanes, approached from the interior of the island.
		for dy in [0,1]:
			var foot := upper + Vector2i(-side * (radius+1),dy)
			land[foot - Vector2i(side,0)] = T.LOW
			land[foot] = T.EAST if side == 1 else T.WEST
			land[foot + Vector2i(side,0)] = T.HIGH
	for i in anchors.size():
		var anchor := anchors[i]
		var link := links[i]
		for t in [0.39,0.62]:
			centers.append(_link_cell(link,anchor,t))
			kinds.append("clearing")
			levels.append(1)
	for d: Vector2i in [Vector2i(0,8),Vector2i(0,-8)]:
		centers.append(START + d)
		kinds.append("clearing")
		levels.append(1)
	var owners := {}
	var queue: Array[Vector2i] = []
	for i in centers.size():
		var c := centers[i]
		if owners.has(c) or land.get(c,T.SEA) != (T.HIGH if levels[i] == 2 else T.LOW):
			return {}
		owners[c] = i
		queue.append(c)
	var index := 0
	while index < queue.size():
		var c := queue[index]
		index += 1
		for d: Vector2i in T.DIRS:
			var n := c + d
			if not land.has(n) or owners.has(n) or (land[n] == T.HIGH) != (land[c] == T.HIGH):
				continue
			owners[n] = owners[c]
			queue.append(n)
	# Remove isolated slivers cut off between the plateau and the shore.
	for c in land.keys():
		if not owners.has(c):
			land.erase(c)
	# The lower surface remains under elevated land only where its original footprint exists.
	var covered := {}
	for c: Vector2i in base:
		if land.get(c,T.SEA) != T.HIGH: continue
		var nearest := 0
		for i in centers.size():
			if levels[i] == 1 and centers[i].distance_squared_to(c) < centers[nearest].distance_squared_to(c):
				nearest = i
		covered[c] = nearest
	# Keep the original plateau centre and its landing clear.
	var middle := {}
	for island in range(1,anchors.size()):
		var plateau := 2 + island*2
		var summit := centers[plateau] + Vector2i(0,1 if island % 2 else -1)
		var footprint: Array[Vector2i] = []
		for dx in range(-2,3):
			for dy in range(-1,3):
				footprint.append(summit + Vector2i(dx,dy))
		var fits := true
		for c in footprint:
			for offset in [Vector2i.ZERO,Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				if land.get(c+offset,T.SEA) != T.HIGH or owners.get(c+offset,-1) != plateau: fits = false
		var foot := summit + Vector2i(-3,0)
		if not fits or land.get(foot+Vector2i.LEFT,T.SEA) != T.HIGH: continue
		centers[plateau] += Vector2i(3,1)
		var id := centers.size()
		centers.append(summit)
		levels.append(3)
		kinds.append("mountain")
		for c in footprint:
			middle[c] = plateau
			owners[c] = id
			land[c] = T.SUMMIT
		land[foot] = T.UPPER_EAST
	if middle.is_empty(): return {}
	# Colour the actual cross-height adjacency graph, including northern edges.
	var choices := ["forest","ruins","mountain","meadow","clearing","rocky"]
	var neighbours := {}
	for c: Vector2i in owners:
		var i: int = owners[c]
		for step in T.DIRS:
			var j: int = owners.get(c+step,i)
			if levels[i] != levels[j]:
				if not neighbours.has(i): neighbours[i] = {}
				neighbours[i][j] = true
	var low_types := ["meadow","forest","forest","forest","mountain" if rng.next_int(0,1) else "ruins"]
	for i in range(low_types.size()-1,0,-1):
		var j := rng.next_int(0,i)
		var saved: String = low_types[i]
		low_types[i] = low_types[j]
		low_types[j] = saved
	for i in low_types.size():
		kinds[1+2*i] = low_types[i]
	for height in [2,3]:
		for i in centers.size():
			if levels[i] != height: continue
			var options := choices
			var start := rng.next_int(0,options.size()-1)
			for j in options.size():
				var candidate: String = options[(start+j)%options.size()]
				if i == 2: candidate = "rocky"
				if j == 0 and i != 2 and "ruins" not in low_types and "ruins" not in kinds.slice(0,i): candidate = "ruins"
				if j == 0 and i != 2 and "mountain" not in low_types and "mountain" not in kinds.slice(0,i): candidate = "mountain"
				var valid := true
				for other in neighbours.get(i,{}):
					if levels[other] < height and not contrasts(candidate,kinds[other]): valid = false
				if valid:
					kinds[i] = candidate
					break
				if j == options.size()-1: return {}
	if not ("mountain" in kinds and "ruins" in kinds): return {}
	var rows: Array = []
	for y in T.SIZE:
		var bytes := PackedByteArray()
		bytes.resize(T.SIZE)
		bytes.fill(T.SEA)
		for x in T.SIZE:
			bytes[x] = land.get(Vector2i(x,y),T.SEA)
		rows.append(bytes.get_string_from_ascii())
	# Flood through actual stair entrances, including both sides of every isthmus.
	var seen := {START:true}
	queue.assign([START])
	index = 0
	while index < queue.size():
		var c := queue[index]
		index += 1
		for d: Vector2i in T.DIRS:
			var n := c + d
			if not seen.has(n) and T.edge(rows,c,n):
				seen[n] = true
				queue.append(n)
	if seen.size() != land.size():
		return {}
	var regions := []
	for i in centers.size():
		var origin := T.center(centers[i])
		regions.append({"id":kinds[i], "level":levels[i], "instanceId":"biome-%02d" % (i+1),
			"isDecorativeOnly":kinds[i] == "clearing",
			"region":{"x":origin.x,"y":origin.y,"shape":"tiles","size":T.TILE,"cells":[],"spawnCells":[]}})
	for c: Vector2i in owners:
		var i: int = owners[c]
		var local := c - centers[i]
		var region: Dictionary = regions[i].region
		var entry := {"x":local.x,"y":local.y}
		region.cells.append(entry)
		region.size = maxf(region.size,(Vector2(local.abs()) + Vector2.ONE * 0.5).length() * T.TILE * 2)
		# Reserve the stair, its landings and a full work position around each resource.
		var interior := true
		for d: Vector2i in T.DIRS:
			if land.get(c+d,T.SEA) != land[c] or T.ramp(land[c]):
				interior = false
				break
		if interior:
			region.spawnCells.append(entry)
	for hidden in [covered,middle]:
		for c: Vector2i in hidden:
			var i: int = hidden[c]
			var region: Dictionary = regions[i].region
			if not region.has("covered"): region.covered = []
			region.covered.append({"x":c.x-centers[i].x,"y":c.y-centers[i].y})
	for biome in regions:
		if biome.region.spawnCells.is_empty():
			return {}
	return {"terrain":rows,"biomes":regions}

# Similar yellow-green and olive tiles need a cooler or lighter neighbour.
static func contrasts(a: String, b: String) -> bool:
	return a != b and not (a in ["mountain","meadow","ruins"] and b in ["mountain","meadow","ruins"])
