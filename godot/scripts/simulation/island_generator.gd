extends RefCounted

const T = preload("res://scripts/simulation/island_terrain.gd")
const Random = preload("res://scripts/simulation/seeded_random.gd")
const START := Vector2i(52,52)
const FALLBACK_SEED := "terrain-reserve-0"
const SECTORS := [Vector2i.RIGHT, Vector2i(1,1), Vector2i.DOWN, Vector2i(-1,1),
	Vector2i.LEFT, Vector2i(-1,-1), Vector2i.UP, Vector2i(1,-1)]

static func generate(seed_text: String) -> Dictionary:
	for attempt in 9:
		var layout_seed := FALLBACK_SEED if attempt == 8 else "%s:islands:%d" % [seed_text,attempt]
		var layout := _layout(Random.new(layout_seed))
		if not layout.is_empty():
			return layout
	push_error("Invalid island fallback")
	return {}

# Short steps on two opposite banks leave the horizontal stair approaches intact.
static func _footprint(rng: Random, rx: int, ry: int) -> Array[Vector2i]:
	var cuts: Array[int] = []
	var max_cut := mini(2,ry-1)
	for i in 4:
		cuts.append(rng.next_int(0,max_cut))
	cuts[3] = (cuts[0]+1) % (max_cut+1)
	var notch := rng.next_int(-rx+2,rx-2)
	var tab := rng.next_int(-rx+2,rx-2)
	var bank := rng.next_int(0,1)*2-1
	var cells: Array[Vector2i] = []
	for x in range(-rx,rx+1):
		for y in range(-ry,ry+1):
			var corner := int(x > 0) + 2*int(y > 0)
			if rx-absi(x) < cuts[corner] and ry-absi(y) < cuts[corner]:
				continue
			if y == bank*ry and x in [notch,notch+1]:
				continue
			cells.append(Vector2i(x,y))
		if x in [tab,tab+1]:
			cells.append(Vector2i(x,-bank*(ry+1)))
	return cells

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
	var stairs: Dictionary = {}
	var centers: Array[Vector2i] = [START]
	var kinds: Array[String] = ["clearing"]
	var levels: Array[int] = [1]
	var owners := {}
	var covered := {}
	var middle := {}
	var anchors: Array[Vector2i] = []
	var links: Array[Vector2i] = []
	var omitted := rng.next_int(0,3)*2+1 if rng.next_int(0,1) else -1
	var sector_centers := {}
	for sector: Vector2i in SECTORS:
		var jitter := Vector2i(rng.next_int(-2,2),rng.next_int(-3,3))
		sector_centers[sector] = START + sector*32 + jitter
	for i in SECTORS.size():
		if i == omitted: continue
		var sector: Vector2i = SECTORS[i]
		anchors.append(sector_centers[sector])
		var link := START
		if sector.x != 0 and sector.y != 0:
			link = sector_centers[Vector2i(sector.x,0)]
		links.append(link)
	# Paint causeways first. Islands then own the banks where the two meet.
	var bridge_start := 1 + 2*anchors.size()
	for i in anchors.size():
		var link := links[i]
		var anchor := anchors[i]
		var length := absi(link.x-anchor.x) + absi(link.y-anchor.y)
		for j in range(length+1):
			var c := _link_cell(link,anchor,float(j)/length)
			for x in range(-2,3):
				for y in range(-2,3):
					var n := c + Vector2i(x,y)
					land[n] = T.LOW
					owners[n] = bridge_start+i
	for local in _footprint(rng,11,10):
		land[START+local] = T.LOW
		owners[START+local] = 0
	var summit_count := rng.next_int(3,4)
	var phase := rng.next_int(0,anchors.size()-1)
	var summits: Array[int] = []
	for i in summit_count:
		summits.append((phase + floori(float(i*anchors.size())/summit_count)) % anchors.size())
	for i in anchors.size():
		var anchor := anchors[i]
		var side := 1 if anchor.x >= START.x else -1
		var low := centers.size()
		centers.append(anchor)
		kinds.append("forest")
		levels.append(1)
		var rx := rng.next_int(8,10)
		for local in _footprint(rng,rx,rng.next_int(6,8)):
			land[anchor+local] = T.LOW
			owners[anchor+local] = low
		var upper := anchor + Vector2i(side*(rx+2),rng.next_int(-1,1))
		var plateau := centers.size()
		centers.append(upper)
		kinds.append("rocky")
		levels.append(2)
		for local in _footprint(rng,5,4):
			var c := upper+local
			if owners.has(c): covered[c] = owners[c]
			land[c] = T.HIGH
			owners[c] = plateau
		for dy in [0,1]:
			var foot := upper + Vector2i(-side*6,dy)
			stairs[foot] = T.EAST if side == 1 else T.WEST
			land[foot] = stairs[foot]
	for i in anchors.size():
		centers.append(_link_cell(links[i],anchors[i],0.5))
		kinds.append("clearing")
		levels.append(1)
	for island in summits:
		var plateau := 2 + island*2
		var summit := centers[plateau]
		var id := centers.size()
		centers[plateau] += Vector2i(3,1)
		centers.append(summit)
		levels.append(3)
		kinds.append("mountain")
		for local in _footprint(rng,2,2):
			var c := summit+local
			# Trim a projection if it would consume the walkable rim.
			if absi(local.y) == 3 and land.get(c+Vector2i(0,signi(local.y)),T.SEA) != T.HIGH:
				continue
			middle[c] = plateau
			owners[c] = id
			land[c] = T.SUMMIT
		for dy in [0,1]:
			var stair := summit + Vector2i(-3,dy)
			stairs[stair] = T.UPPER_EAST
			land[stair] = stairs[stair]
	var low_types := ["meadow","forest","forest","forest","mountain" if rng.next_int(0,1) else "ruins"]
	while low_types.size() < anchors.size():
		low_types.append("meadow" if low_types.size()%2 else "forest")
	for i in range(low_types.size()-1,0,-1):
		var j := rng.next_int(0,i)
		var saved: String = low_types[i]
		low_types[i] = low_types[j]
		low_types[j] = saved
	for i in low_types.size():
		kinds[1+2*i] = low_types[i]
	# Inset patches share their island's elevation and keep the terrace rim intact.
	var starter_meadow := centers.size()
	_add_low_patch(START + Vector2i(0,4), 0, "meadow", owners, centers, kinds, levels)
	for island in range(0,anchors.size(),2):
		var parent := 1 + 2 * island
		var inland := -1 if anchors[island].x >= START.x else 1
		var patch := anchors[island] + Vector2i(inland*4,rng.next_int(-1,1))
		_add_low_patch(patch,parent,"clearing" if kinds[parent] == "forest" else "forest",owners,centers,kinds,levels)
	# A terrace may cut off a corner of its lower biome while the island as
	# a whole remains reachable. Sheep must be able to stay in their biome.
	if not _regions_connected(owners,centers):
		return {}
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
	for stair: Vector2i in stairs:
		if T.code(rows,stair) != stairs[stair] or not T.edge(rows,stair,stair+Vector2i.LEFT) or not T.edge(rows,stair,stair+Vector2i.RIGHT):
			return {}
	# Flood through actual stair entrances, including both sides of every isthmus.
	var seen := {START:true}
	var queue: Array[Vector2i] = [START]
	var index := 0
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
	regions[starter_meadow].startingMeadow = true
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

static func _add_low_patch(origin: Vector2i, parent: int, kind: String, owners: Dictionary, centers: Array[Vector2i], kinds: Array[String], levels: Array[int]) -> void:
	var id := centers.size()
	centers.append(origin)
	kinds.append(kind)
	levels.append(1)
	for y in range(-2,3):
		for x in range(-2,3):
			var c := origin + Vector2i(x,y)
			if x*x + y*y <= 6 and owners.get(c,-1) == parent:
				owners[c] = id

static func _regions_connected(owners: Dictionary, centers: Array[Vector2i]) -> bool:
	var queue: Array[Vector2i] = centers.duplicate()
	var seen := {}
	for i in centers.size():
		if owners.get(centers[i],-1) != i: return false
		seen[centers[i]] = true
	var index := 0
	while index < queue.size():
		var c := queue[index]
		index += 1
		for d: Vector2i in T.DIRS:
			var n := c+d
			if not seen.has(n) and owners.get(n,-1) == owners[c]:
				seen[n] = true
				queue.append(n)
	return seen.size() == owners.size()

# Similar yellow-green and olive tiles need a cooler or lighter neighbour.
static func contrasts(a: String, b: String) -> bool:
	return a != b and not (a in ["mountain","meadow","ruins"] and b in ["mountain","meadow","ruins"])
