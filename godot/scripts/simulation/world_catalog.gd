class_name TribeWorldCatalog
extends RefCounted
## Pure procedural data. No nodes or Godot global RNG; Godot vegetation replaces the legacy decoration.

const Random = preload("res://scripts/simulation/seeded_random.gd")
const RESOURCE_BIOMES := ["meadow", "forest", "rocky", "ruins"]
const RESOURCE_TYPES := ["food", "wood", "stone", "spark"]
const DEFINITIONS := {
	"clearing": ["Claro", 1.0, ["wood"], ""],
	"meadow": ["Pradera", 1.0, ["food"], "food"],
	"forest": ["Bosque", 0.8, ["wood"], "wood"],
	"rocky": ["Pedregal", 0.65, ["stone"], "stone"],
	"ruins": ["Ruinas", 0.75, ["spark"], "spark"],
	"great-fire": ["Gran Hoguera", 1.0, [], ""], # Legacy data only; no victory.
}
const HITO_3 := {
	"totalBiomes": 10, "minRadius": 7.0, "maxRadius": 11.0,
	"minimumBiomeGap": 0.5, "maxPlacementAttempts": 320,
	"minResourceNodesPerBiome": 1, "maxResourceNodesPerBiome": 3,
	"secondaryChance": 0.38, "secondaryAmountMultiplier": 0.4,
	"worldPadding": 4.0, "startingBiomeRadius": 5.0,
	"startingResourceExclusionRadius": 12.0, "decorativeBiomeCount": 12,
	"decorativeBiomeMinRadius": 3.0, "decorativeBiomeMaxRadius": 5.0,
	"activeResourceTypes": RESOURCE_TYPES,
}
const SOURCES := {"food": "berry-bush", "wood": "tree", "stone": "stone-vein", "spark": "ruin"}
const RADII := {"food": 1.45, "wood": 1.35, "stone": 1.35, "spark": 1.3}
const DECORATIONS := {
	"clearing": [12, 18, [["grass", 60], ["bush", 25], ["mushroom", 15]]],
	"meadow": [18, 26, [["grass", 60], ["bush", 25], ["mushroom", 15]]],
	"forest": [16, 24, [["grass", 58], ["bush", 27], ["mushroom", 15]]],
	"rocky": [0, 0, []], "ruins": [0, 0, []],
	"great-fire": [0, 0, []],
}

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

static func _outside_start(random: Random, center: Dictionary, radius: float, exclusion: float) -> Dictionary:
	var point := point_in_circle(random, center, radius)
	for attempt in 64:
		if _distance(point, {"x": 80, "y": 80}) >= exclusion:
			return point
		point = point_in_circle(random, center, radius)
	return point

static func create_biomes(seed_text: String, config: Dictionary = HITO_3) -> Array:
	var random := Random.new(seed_text + ":biomes")
	var resource_count := maxi(int(ceil(config.totalBiomes)), RESOURCE_BIOMES.size())
	var decorative_count := maxi(int(floor(config.decorativeBiomeCount)), 0)
	var radius_min := maxf(config.minRadius, 2)
	var radius_max := maxf(config.maxRadius, radius_min)
	var padding := maxf(config.worldPadding, 0)
	var gap := maxf(config.minimumBiomeGap, 0)
	var placed: Array = []
	var biomes: Array = []
	for index in resource_count + decorative_count + 1:
		var resource_index := index - 1
		var is_resource := resource_index >= 0 and resource_index < resource_count
		var biome := "clearing"
		if is_resource:
			biome = RESOURCE_BIOMES[resource_index] if resource_index < RESOURCE_BIOMES.size() else RESOURCE_BIOMES[random.next_int(0, RESOURCE_BIOMES.size() - 1)]
		var selected: Dictionary = {}
		if index == 0:
			selected = {"x": 80, "y": 80, "radius": minf(maxf(config.startingBiomeRadius, 2), radius_min - 0.1)}
		else:
			for attempt in maxi(config.maxPlacementAttempts, 1):
				var radius: float
				if not is_resource:
					radius = random.next_float(maxf(config.decorativeBiomeMinRadius, 2), maxf(maxf(config.decorativeBiomeMaxRadius, config.decorativeBiomeMinRadius), 2))
				else:
					radius = random.next_float(radius_min, radius_max)
				var candidate := {"x": random.next_float(padding + radius, 160 - padding - radius), "y": random.next_float(padding + radius, 160 - padding - radius), "radius": radius}
				var valid := true
				for other in placed:
					if _distance(candidate, other) + 0.0001 < candidate.radius + other.radius + gap:
						valid = false
						break
				if valid:
					selected = candidate
					break
		if selected.is_empty():
			push_error("Unable to place biome without overlap: " + biome)
			return []
		placed.append(selected)
		biomes.append({
			"id": biome, "instanceId": "biome-%02d" % (index + 1),
			"isDecorativeOnly": not is_resource,
			"displayName": DEFINITIONS[biome][0], "movementMultiplier": DEFINITIONS[biome][1],
			"visibleResourceTypes": DEFINITIONS[biome][2].duplicate(),
			"region": {"x": _round_position(clampf(selected.x, padding + selected.radius, 160 - padding - selected.radius)), "y": _round_position(clampf(selected.y, padding + selected.radius, 160 - padding - selected.radius)), "size": _round_position(selected.radius * 2), "shape": "circle"},
		})
	return biomes

static func create_resources(seed_text: String, biomes: Array, config: Dictionary = HITO_3) -> Array:
	var random := Random.new(seed_text + ":resources")
	var twig_random := Random.new(seed_text + ":twig-clearings")
	var tree_random := Random.new(seed_text + ":tree-yields")
	var active: Array = []
	for resource_type in config.get("activeResourceTypes", RESOURCE_TYPES):
		if resource_type in RESOURCE_TYPES and resource_type not in active:
			active.append(resource_type)
	var nodes: Array = []
	for biome in biomes:
		if biome.isDecorativeOnly:
			continue
		var primary: String = DEFINITIONS[biome.id][3]
		if primary.is_empty() or primary not in active:
			continue
		var secondary := active.duplicate()
		secondary.erase(primary)
		var minimum := maxi(0, int(floor(config.minResourceNodesPerBiome)))
		var count := random.next_int(minimum, maxi(minimum, int(floor(config.maxResourceNodesPerBiome))))
		for index in count:
			var is_secondary: bool = not secondary.is_empty() and index > 0 and random.next_float() < config.secondaryChance
			var resource_type: String = secondary[random.next_int(0, secondary.size() - 1)] if is_secondary else primary
			var primary_amount := random.next_int(1, 1)
			var amount := maxi(1, int(floor(primary_amount * clampf(config.secondaryAmountMultiplier, 0, 0.99)))) if is_secondary else primary_amount
			var point := _outside_start(random, {"x": biome.region.x, "y": biome.region.y}, biome.region.size / 2.0, maxf(config.startingResourceExclusionRadius, 0))
			var node := {
				"id": "resource-%03d" % (nodes.size() + 1), "type": resource_type,
				"source": SOURCES[resource_type], "biome": biome.id, "biomeInstanceId": biome.instanceId,
				"isSecondary": is_secondary, "interactionRadius": RADII[resource_type],
				"position": point, "amount": amount, "maxAmount": amount, "gatherRate": 1, "tier": 1,
			}
			if resource_type == "wood":
				node.yieldAmount = tree_random.next_int(2, 3)
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
		var maximum_offset := maxf(biome.region.size / 2.0 - 0.8, 0.75)
		var point := point_in_circle(twig_random, {"x": biome.region.x, "y": biome.region.y}, maximum_offset, minf(1, maximum_offset * 0.5))
		nodes.append({
			"id": "resource-%03d" % (nodes.size() + 1), "type": "wood", "source": "twigs",
			"biome": biome.id, "biomeInstanceId": biome.instanceId, "isSecondary": true,
			"interactionRadius": 1.2, "position": point, "amount": 1, "maxAmount": 1,
			"gatherRate": 1, "tier": 1, "yieldAmount": 2,
		})
	return nodes

static func _shuffle(values: Array, random: Random) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := random.next_int(0, index)
		var temporary: Variant = values[index]
		values[index] = values[swap_index]
		values[swap_index] = temporary

static func create_barbarians(seed_text: String) -> Array:
	var random := Random.new(seed_text + ":barbarian-spawns")
	var spawns: Array = []
	for index in 5:
		var position: Dictionary = {}
		for attempt in 500:
			var candidate := {"x": _round_position(random.next_float(10, 150)), "y": _round_position(random.next_float(10, 150))}
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
	for index in 6:
		var biome: Dictionary = meadows[index % meadows.size()]
		var center := {"x": biome.region.x, "y": biome.region.y}
		var radius := maxf(biome.region.size / 2.0 - 0.8, 0.5)
		var point := point_in_circle(random, center, radius)
		rabbits.append({
			"id": "rabbit-%02d" % (index + 1), "kind": "rabbit", "position": point,
			"spawnPosition": point.duplicate(), "homeCenter": center, "homeRadius": radius,
			"patrolTarget": point_in_circle(random, center, radius), "health": 2, "maxHealth": 2,
			"isAlive": true, "respawnRemainingSeconds": 0, "attackProgressSeconds": 0, "spawnCycle": 0,
		})
	return rabbits

static func _decoration_kinds(count: int, distribution: Array, random: Random) -> Array:
	var allocations: Array = []
	var total_weight := 0.0
	for entry in distribution:
		total_weight += entry[1]
	var remaining := count
	for entry in distribution:
		var exact: float = count * entry[1] / total_weight
		var assigned := int(floor(exact))
		if entry[0] == "mushroom":
			assigned = mini(assigned, 2)
		allocations.append({"kind": entry[0], "count": assigned, "remainder": exact - assigned})
		remaining -= assigned
	while remaining > 0:
		var best: Dictionary = {}
		for entry in allocations:
			if entry.kind == "mushroom" and entry.count >= 2:
				continue
			if best.is_empty() or entry.remainder > best.remainder:
				best = entry
		if best.is_empty():
			break
		best.count += 1
		best.remainder = 0
		remaining -= 1
	var kinds: Array = []
	for entry in allocations:
		for index in entry.count:
			kinds.append(entry.kind)
	_shuffle(kinds, random)
	return kinds

static func create_decorations(seed_text: String, biomes: Array) -> Array:
	var random := Random.new(seed_text + ":decorations")
	var decorations: Array = []
	for biome in biomes:
		var rule: Array = DECORATIONS[biome.id]
		var count := random.next_int(rule[0], rule[1])
		var radius := maxf(biome.region.size / 2.0 - 1.2, 0)
		for kind in _decoration_kinds(count, rule[2], random):
			var decoration := {
				"id": "decoration-%03d" % (decorations.size() + 1), "kind": kind,
				"biome": biome.id, "biomeInstanceId": biome.instanceId,
				"position": point_in_circle(random, {"x": biome.region.x, "y": biome.region.y}, radius, minf(1.5, radius)),
				"scale": _round_position(random.next_float(1.26, 1.62)),
			}
			decorations.append(decoration)
	return decorations

static func create_blueprint(seed_text: String) -> Dictionary:
	var biomes := create_biomes(seed_text)
	return {"seed": seed_text, "biomes": biomes, "resources": create_resources(seed_text, biomes), "decorations": create_decorations(seed_text, biomes)}
