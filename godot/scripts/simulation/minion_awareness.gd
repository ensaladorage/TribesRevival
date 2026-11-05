class_name TribeMinionAwareness
extends RefCounted
## Current sightings only; no unseen memory or recursive communication.

const Geo = preload("res://scripts/simulation/geometry.gd")

static func choose_calls(units: Array, entities: Array, enemy_radius: float, animal_radius: float, can_respond: Callable = Callable()) -> Dictionary:
	var calls := {}
	var seen: Array = []
	for entity in entities:
		if not entity.isAlive:
			continue
		for unit in units:
			if Geo.distance(unit.position, entity.position) <= (enemy_radius if entity.kind == "combat" else animal_radius):
				seen.append(entity)
				break
	seen.sort_custom(func(a, b):
		if a.kind != b.kind:
			return a.kind == "combat"
		return a.id < b.id)
	var assigned := {}
	var ordered := units.duplicate()
	ordered.sort_custom(func(a, b): return a.id < b.id)
	for unit in ordered:
		for entity in seen:
			if entity.id != unit.get("currentTargetId") or entity.kind != unit.currentKind:
				continue
			if not (unit.canFight if entity.kind == "combat" else unit.canHunt):
				continue
			calls[unit.id] = {"kind": entity.kind, "targetId": entity.id}
			assigned[entity.kind + ":" + entity.id] = true
			break
	for entity in seen:
		var key: String = entity.kind + ":" + entity.id
		if assigned.has(key):
			continue
		var candidates: Array = []
		for unit in units:
			if unit.available and not calls.has(unit.id) and (unit.canFight if entity.kind == "combat" else unit.canHunt) and (not can_respond.is_valid() or can_respond.call(unit, entity)):
				candidates.append(unit)
		candidates.sort_custom(func(a, b):
			var difference := Geo.distance(a.position, entity.position) - Geo.distance(b.position, entity.position)
			return difference < 0 if difference != 0 else a.id < b.id)
		if not candidates.is_empty():
			calls[candidates[0].id] = {"kind": entity.kind, "targetId": entity.id}
			assigned[key] = true
	return calls
