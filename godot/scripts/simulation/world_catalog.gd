class_name TribeWorldCatalog
extends RefCounted
## Pure procedural data. No nodes or Godot global RNG; Godot vegetation replaces the legacy decoration.

const Random = preload("res://scripts/simulation/seeded_random.gd")
const Footprint = preload("res://scripts/simulation/biome_footprint.gd")
const Islands = preload("res://scripts/simulation/island_generator.gd")
const Terrain = preload("res://scripts/simulation/island_terrain.gd")
const Vegetation = preload("res://scripts/simulation/vegetation_profile.tres")
const RESOURCE_TYPES := ["food", "wood", "stone", "spark"]
const DEFINITIONS := {
	"clearing": ["Claro", 1.0, ["wood"], ""],
	"meadow": ["Pradera", 1.0, ["food"], "food"],
	"mountain": ["Montaña", 1.0, ["stone","wood","food"], "stone"],
	"forest": ["Bosque", 0.8, ["wood"], "wood"],
	"rocky": ["Pedregal", 0.65, ["stone"], "stone"],
	"ruins": ["Ruinas", 0.75, ["spark"], "spark"],
	"great-fire": ["Gran Hoguera", 1.0, [], ""], # Legacy data only; no victory.
}
const HITO_3 := {
	"minResourceNodesPerBiome": 1, "maxResourceNodesPerBiome": 3,
	"secondaryChance": 0.38, "secondaryAmountMultiplier": 0.4,
	"startingResourceExclusionRadius": 12.0,
	"activeResourceTypes": RESOURCE_TYPES,
}
const SOURCES := {"food": "berry-bush", "wood": "tree", "stone": "stone-vein", "spark": "ruin"}
const RADII := {"food": 1.45, "wood": 1.35, "stone": 1.35, "spark": 1.3}
static func _round_position(value: float) -> float:
	return floor(value * 100.0 + 0.5) / 100.0

static func _distance(first: Dictionary, second: Dictionary) -> float:
	var dx: float = first.x - second.x
	var dy: float = first.y - second.y
	return sqrt(dx * dx + dy * dy)

static func point_in_circle(random: Random, center: Dictionary, radius: float, inner_radius: float = 0.0) -> Dictionary:
	var angle := random.next_float(0, TAU)
	var distance := sqrt(random.next_float(inner_radius * inner_radius, radius * radius))
	return {"x": _round_position(center.x + cos(angle) * distance), "y": _round_position(center.y + sin(angle) * distance)}

static func _describe(world: Dictionary) -> void:
	for biome in world.biomes:
		var definition: Array = DEFINITIONS[biome.id]
		biome.displayName = definition[0]
		biome.movementMultiplier = definition[1]
		biome.visibleResourceTypes = definition[2].duplicate()

static func create_biomes(seed_text: String) -> Array:
	return create_blueprint(seed_text).biomes

static func create_resources(seed_text: String, biomes: Array, config: Dictionary = HITO_3, terrain: Array = []) -> Array:
	var random := Random.new(seed_text + ":resources")
	var twig_random := Random.new(seed_text + ":twig-clearings")
	var active: Array = []
	for resource_type in config.get("activeResourceTypes", RESOURCE_TYPES):
		if resource_type in RESOURCE_TYPES and resource_type not in active:
			active.append(resource_type)
	var nodes: Array = []
	var stair_front := _stair_clearance(terrain)
	for biome in biomes:
		if biome.isDecorativeOnly:
			continue
		var primary: String = DEFINITIONS[biome.id][3]
		if primary.is_empty() or primary not in active:
			continue
		var secondary := active.duplicate()
		secondary.erase(primary)
		if biome.id == "mountain":
			secondary = active.filter(func(t): return t in ["wood","food"])
		elif biome.level == 1:
			secondary.erase("stone")
			secondary.erase("spark")
		var minimum := maxi(0, int(floor(config.minResourceNodesPerBiome)))
		var count := random.next_int(minimum, maxi(minimum, int(floor(config.maxResourceNodesPerBiome))))
		var types: Array = []
		for index in count:
			var extra: bool = index > 0 and not secondary.is_empty() and random.next_float() < config.secondaryChance
			types.append(secondary[random.next_int(0,secondary.size()-1)] if extra else primary)
		if biome.get("startingMeadow",false):
			types = ["food","wood"].filter(func(t): return t in active)
		elif biome.id == "forest":
			types.clear()
			for index in random.next_int(5,8): types.append("wood")
		elif biome.id == "rocky":
			types.clear()
			for index in random.next_int(4,6): types.append("stone")
		elif biome.id == "meadow" and "wood" in active:
			types = types.filter(func(t): return t != "wood")
			for index in random.next_int(2,4): types.append("wood")
		var exclusion: float = 3.0 if biome.get("startingMeadow",false) else config.startingResourceExclusionRadius
		var cells := Footprint.eligible(biome.region, exclusion).duplicate()
		_shuffle(cells, random)
		var cluster := Vector2.INF
		for index in types.size():
			var resource_type: String = types[index]
			var is_secondary := resource_type != primary
			var amount := 1
			var isolated: bool = biome.id == "meadow" and resource_type == "wood" and index == types.size()-1 and random.next_int(0,3) == 0
			# Put the first quarry within working distance of its clear landing.
			if biome.id == "rocky" and biome.instanceId == "biome-03" and index == 0:
				cluster = Vector2(biome.region.x,biome.region.y)
			var point := _resource_point(biome.region,cells,nodes,cluster,isolated,stair_front if resource_type == "wood" else {})
			if point.is_empty():
				break
			if not cluster.is_finite() or (biome.id == "forest" and index == 4 and types.size() >= 7):
				cluster = Vector2(point.x,point.y)
			var node := {
				"id": "resource-%03d" % (nodes.size() + 1), "type": resource_type,
				"source": SOURCES[resource_type], "biome": biome.id, "biomeInstanceId": biome.instanceId,
				"isSecondary": is_secondary, "interactionRadius": RADII[resource_type],
				"position": point, "amount": amount, "maxAmount": amount, "gatherRate": 1, "tier": 1,
			}
			nodes.append(node)
	var clearings: Array = biomes.filter(func(biome): return biome.id == "clearing")
	if clearings.is_empty():
		return nodes
	var starting: Dictionary = clearings[0]
	for biome in clearings:
		if absf(biome.region.x - 80) < 0.01 and absf(biome.region.y - 80) < 0.01:
			starting = biome
			break
	var others: Array = clearings.filter(func(biome): return biome.instanceId != starting.instanceId)
	_shuffle(others, twig_random)
	var twig_clearings: Array = [starting]
	twig_clearings.append_array(others.slice(0, maxi(int(ceil(clearings.size() * 0.5)) - 1, 0)))
	for biome in twig_clearings:
		var point := Footprint.sample(biome.region, twig_random, biome.region.spawnCells)
		nodes.append({
			"id": "resource-%03d" % (nodes.size() + 1), "type": "wood", "source": "twigs",
			"biome": biome.id, "biomeInstanceId": biome.instanceId, "isSecondary": true,
			"interactionRadius": 1.2, "position": point, "amount": 1, "maxAmount": 1,
			"gatherRate": 1, "tier": 1,
		})
	return nodes

static func _stair_clearance(rows: Array) -> Dictionary:
	var reserved := {}
	for y in rows.size():
		for x in Terrain.SIZE:
			var stair := Vector2i(x,y)
			if not Terrain.ramp(Terrain.code(rows,stair)): continue
			for dx in range(-2,3):
				for dy in range(-1,4):
					reserved[stair+Vector2i(dx,dy)] = true
	return reserved

static func _resource_point(region: Dictionary, cells: Array, nodes: Array, cluster: Vector2, isolated: bool, excluded: Dictionary) -> Dictionary:
	var best := Vector2.INF
	var best_index := -1
	var best_distance := INF
	for i in cells.size():
		var point := Footprint.center(region,cells[i])
		if excluded.has(Terrain.cell({"x":point.x,"y":point.y})): continue
		if nodes.any(func(node): return point.distance_squared_to(Vector2(node.position.x,node.position.y)) < 2.2):
			continue
		var distance := point.distance_squared_to(cluster) if cluster.is_finite() else 0.0
		var score := -distance if isolated else distance
		if score < best_distance:
			best_index = i
			best = point
			best_distance = score
	if best_index < 0:
		return {}
	cells.remove_at(best_index)
	return {"x":best.x,"y":best.y}

static func _shuffle(values: Array, random: Random) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := random.next_int(0, index)
		var temporary: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary

static func create_barbarians(seed_text: String, terrain: Array = []) -> Array:
	var random := Random.new(seed_text + ":barbarian-spawns")
	var spawns: Array = []
	for index in 5:
		var position: Dictionary = {}
		for attempt in 500:
			var candidate := {"x": _round_position(random.next_float(10, 150)), "y": _round_position(random.next_float(10, 150))}
			if not Terrain.fits(terrain, candidate, 0.7, true):
				continue
			var valid := _distance(candidate, {"x": 80, "y": 80}) >= 24
			for other in spawns:
				if _distance(candidate, other) < 18:
					valid = false
			if valid:
				position = candidate
				break
		if position.is_empty():
			push_error("Unable to place deterministic barbarian spawns")
			return []
		spawns.append(position)
	var barbarians: Array = []
	for index in spawns.size():
		var point: Dictionary = spawns[index]
		barbarians.append({
			"id": "barbarian-%02d" % (index + 1), "position": point.duplicate(),
			"spawnPosition": point.duplicate(), "patrolCenter": point.duplicate(), "patrolTarget": point.duplicate(),
			"patrolRadius": 3.5, "patrolWaitRemainingSeconds": random.next_float(2, 4), "patrolStep": 0,
			"returningToSpawn": false, "health": 5, "maxHealth": 5, "isAlive": true,
			"respawnRemainingSeconds": 0, "attackProgressSeconds": 2.5, "targetUnitId": null,
			"alertedUnitIds": [], "alertSoundedThisEncounter": false, "spawnCycle": 0,
		})
	return barbarians

static func create_rabbits(seed_text: String, biomes: Array) -> Array:
	var meadows: Array = biomes.filter(func(biome): return biome.id == "meadow" and not biome.isDecorativeOnly)
	if meadows.is_empty():
		return []
	var random := Random.new(seed_text + ":rabbit-spawns")
	var rabbits: Array = []
	var starting := meadows.filter(func(b): return b.get("startingMeadow",false))
	var others := meadows.filter(func(b): return not b.get("startingMeadow",false))
	for index in 6:
		var biome: Dictionary = meadows[index % meadows.size()]
		if not starting.is_empty():
			biome = starting[0] if index < 2 or others.is_empty() else others[(index-2) % others.size()]
		var center := {"x": biome.region.x, "y": biome.region.y}
		var radius := maxf(biome.region.size / 2.0 - 0.8, 0.5)
		var use_cells: bool = biome.region.has("spawnCells")
		var point := Footprint.sample(biome.region, random, biome.region.spawnCells) if use_cells else point_in_circle(random, center, radius)
		var target := Footprint.sample(biome.region, random, biome.region.spawnCells) if use_cells else point_in_circle(random, center, radius)
		var animal := {
			"id": "rabbit-%02d" % (index + 1), "kind": "rabbit", "position": point,
			"spawnPosition": point.duplicate(), "homeCenter": center, "homeRadius": radius,
			"patrolTarget": target, "health": 2, "maxHealth": 2,
			"isAlive": true, "respawnRemainingSeconds": 0, "attackProgressSeconds": 0, "spawnCycle": 0,
		}
		if use_cells:
			animal.homeBiomeId = biome.instanceId
		rabbits.append(animal)

	return rabbits

static func create_decorations(seed_text: String, biomes: Array, resources: Array = [], terrain: Array = []) -> Array:
	var random := Random.new(seed_text + ":decoration-groups")
	var decorations: Array = []
	var stair_front := _stair_clearance(terrain)
	var reserved: Array[Vector2] = []
	for biome in biomes:
		if biome.id not in ["clearing","meadow","forest"]: continue
		var region: Dictionary = biome.region
		var cells: Array = region.spawnCells.duplicate()
		_shuffle(cells,random)
		# Leave the stair approach visible from the fixed camera to the south.
		var origin := Terrain.cell(region)
		if not terrain.is_empty():
			cells = cells.filter(func(tile): return not stair_front.has(origin+Vector2i(tile.x,tile.y)))
			var borders: Array = []
			var interior: Array = []
			for tile in cells:
				var c := origin + Vector2i(tile.x,tile.y)
				var k := Terrain.code(terrain,c)
				if Terrain.DIRS.any(func(d): return Terrain.code(terrain,c+d*2) != k):
					borders.append(tile)
				else:
					interior.append(tile)
			cells = borders + interior
		_place_group(decorations,reserved,resources,biome,cells,"bush",random.next_int(2,3),1.05)
		_place_group(decorations,reserved,resources,biome,cells,"grass",random.next_int(3,Vegetation.grass_group_max),0.8)
		if random.next_float() < Vegetation.mushroom_chance:
			_place_group(decorations,reserved,resources,biome,cells,"mushroom",1,0.6)
	if not terrain.is_empty():
		_place_water_rocks(decorations, terrain, Random.new(seed_text + ":water-rocks"))
	return decorations

static func _place_group(result: Array, reserved: Array[Vector2], resources: Array, biome: Dictionary,
		cells: Array, kind: String, count: int, spacing: float) -> void:
	var region: Dictionary = biome.region
	var allowed := {}
	var origin := Terrain.cell(region)
	for cell in cells:
		allowed[origin + Vector2i(cell.x,cell.y)] = true
	for cell in cells:
		var center := Footprint.center(region,cell)
		var group: Array[Vector2] = []
		for index in count:
			var offset := Vector2.ZERO if index == 0 else Vector2.from_angle(TAU * index / count) * spacing * Vegetation.group_spacing
			var point := center + offset
			if not allowed.has(Terrain.cell({"x":point.x,"y":point.y})) or point.distance_to(Footprint.START) < 4.0:
				break
			if reserved.any(func(p): return point.distance_to(p) < 1.15):
				break
			if resources.any(func(n): return point.distance_to(Vector2(n.position.x,n.position.y)) < 2.5):
				break
			group.append(point)
		if group.size() != count: continue
		for point in group:
			_append_decoration(result,point,kind,biome.id,biome.instanceId)
		reserved.append_array(group)
		return

static func _append_decoration(result: Array, point: Vector2, kind: String, biome: String, instance_id: String) -> void:
	result.append({"id":"grouped-%03d" % result.size(),"kind":kind,"biome":biome,
		"biomeInstanceId":instance_id,"position":{"x":point.x,"y":point.y},"scale":1.0,"grouped":true})

static func _place_water_rocks(result: Array, terrain: Array, random: Random) -> void:
	var candidates: Array[Vector2i] = []
	for y in range(4,Terrain.SIZE-4):
		for x in range(4,Terrain.SIZE-4):
			var cell := Vector2i(x,y)
			if not Terrain.DIRS.any(func(d): return Terrain.code(terrain,cell+d*4) != Terrain.SEA): continue
			var clear := true
			for dx in range(-1,2):
				for dy in range(-2,3):
					if Terrain.code(terrain,cell+Vector2i(dx,dy)) != Terrain.SEA: clear = false
			if clear:
				candidates.append(cell)
	_shuffle(candidates,random)
	var anchors: Array[Vector2i] = []
	var baseline_count := 0
	for cell in candidates:
		if anchors.any(func(anchor): return cell.distance_squared_to(anchor) < 81.0):
			continue
		anchors.append(cell)
		baseline_count += 1
		if anchors.size() % 3 == 0 and Terrain.DIRS.any(func(direction): return cell + direction * 2 in candidates):
			baseline_count += 1
		if anchors.size() >= 12:
			break

	var remaining := baseline_count * 3
	var rocks: Array[Vector2i] = []
	var group_sizes := [2, 3, 4, 5]
	_shuffle(group_sizes, random)
	# Start with the former coastal anchors, then try alternate centers for narrower bays.
	for center in anchors + candidates:
		if remaining < 2:
			break
		if rocks.any(func(rock): return center.distance_squared_to(rock) <= 16.0):
			continue
		var desired := mini(group_sizes[0], remaining)
		if remaining - desired == 1 and desired < 5:
			desired += 1
		var group: Array[Vector2i] = [center]
		for cell in candidates:
			var distance := center.distance_squared_to(cell)
			if distance < 4.0 or distance > 16.0:
				continue
			if rocks.any(func(rock): return cell.distance_squared_to(rock) <= 16.0):
				continue
			if group.any(func(rock): return cell.distance_squared_to(rock) < 4.0):
				continue
			group.append(cell)
			if group.size() == desired:
				break
		if group.size() != desired:
			continue
		rocks.append_array(group)
		remaining -= group.size()
		group_sizes.append(group_sizes.pop_front())

	# Leave a few isolated rocks where the coast cannot support another group.
	for cell in candidates:
		if remaining == 0:
			break
		if rocks.any(func(rock): return cell.distance_squared_to(rock) <= 16.0):
			continue
		rocks.append(cell)
		remaining -= 1

	for cell in rocks:
		var point := Terrain.center(cell)
		_append_decoration(result,Vector2(point.x,point.y),"water-rock","","")

const Reserve = preload("res://scripts/simulation/landscape_reserve.res")

static func create_blueprint(seed_text: String, profile: Islands.ProfileType = Islands.Profile) -> Dictionary:
	for attempt in 8:
		var world := Islands.candidate(seed_text,attempt,profile)
		if world.is_empty(): continue
		_describe(world)
		var nodes := create_resources(seed_text,world.biomes,HITO_3,world.terrain)
		if not _usable_resources(world,nodes): continue
		var enemies := create_barbarians(seed_text,world.terrain)
		if enemies.size() != 5: continue
		world.seed = seed_text
		world.resources = nodes
		world.barbarians = enemies
		world.animals = create_rabbits(seed_text,world.biomes)
		world.decorations = create_decorations(seed_text,world.biomes,nodes,world.terrain)
		return world
	push_warning("Landscape reserve used for seed %s after eight candidates" % seed_text)
	var world: Dictionary = Reserve.blueprint.duplicate(true)
	world.seed = seed_text
	return world

static func _usable_resources(world: Dictionary, nodes: Array) -> bool:
	var counts := {}
	for node in nodes:
		var id: String = node.biomeInstanceId
		if not counts.has(id): counts[id] = {}
		counts[id][node.type] = counts[id].get(node.type,0) + 1
		# All surface cells already connect to START through legal stair edges.
		# Verify an actual interaction position on this connected surface.
		if Terrain.work_position(world.terrain,node.position,node).is_empty(): return false
	for biome in world.biomes:
		if biome.isDecorativeOnly: continue
		var resources: Dictionary = counts.get(biome.instanceId,{})
		if not resources.has(DEFINITIONS[biome.id][3]): return false
		if biome.id == "forest" and resources.get("wood",0) < 5: return false
		if biome.id == "rocky" and resources.get("stone",0) < 4: return false
		if biome.id == "meadow":
			var required := 1 if biome.get("startingMeadow",false) else 2
			if resources.get("wood",0) < required: return false
	return true
