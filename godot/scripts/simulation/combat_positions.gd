class_name TribeCombatPositions
extends RefCounted

const Geo = preload("res://scripts/simulation/geometry.gd")

static func position_radius(attack_range: float, ranged: bool) -> float:
	return attack_range - (0.4 if ranged else 0.02)

static func _has_slot(attacker: Dictionary) -> bool:
	var offset: Variant = attacker.get("offset")
	return offset != null and absf(Geo.length(offset) - position_radius(attacker.range, attacker.ranged)) <= 0.05

static func _is_free(attacker: Dictionary, point: Dictionary, used: Array, is_allowed: Callable) -> bool:
	if not is_allowed.call(attacker, point):
		return false
	for other in used:
		if Geo.distance(point, other) < 0.96 - 1e-7:
			return false
	return true

static func assign(target: Dictionary, attackers: Array, occupied: Array, is_allowed: Callable) -> Dictionary:
	var result := {}
	var used := occupied.duplicate()
	var ordered := attackers.duplicate()
	ordered.sort_custom(func(a, b):
		if _has_slot(a) != _has_slot(b):
			return _has_slot(a)
		return a.id < b.id)
	for attacker in ordered:
		if not _has_slot(attacker):
			continue
		var point := {"x": target.x + attacker.offset.x, "y": target.y + attacker.offset.y}
		if _is_free(attacker, point, used, is_allowed):
			result[attacker.id] = point
			used.append(point)
	for attacker in ordered:
		if result.has(attacker.id):
			continue
		var radius := position_radius(attacker.range, attacker.ranged)
		var candidates: Array = []
		var offset: Variant = attacker.get("offset")
		if offset != null:
			var offset_length := Geo.length(offset)
			if offset_length >= radius - 0.05 and offset_length <= radius + 0.05:
				candidates.append({"x": target.x + offset.x, "y": target.y + offset.y})
		if absf(Geo.distance(attacker.position, target) - radius) <= 0.05:
			candidates.append(attacker.position)
		var count := 24 if attacker.ranged else 6
		var ring: Array = []
		for index in count:
			ring.append({"x": target.x + cos(index * PI * 2.0 / count) * radius, "y": target.y + sin(index * PI * 2.0 / count) * radius})
		ring = Geo.stable_sorted(ring, func(a, b): return Geo.distance(attacker.position, a) < Geo.distance(attacker.position, b))
		candidates.append_array(ring)
		var selected: Variant = null
		for point in candidates:
			if _is_free(attacker, point, used, is_allowed):
				selected = point
				break
		if selected == null and not attacker.ranged:
			var waiting: Array = []
			for index in 12:
				waiting.append({"x": target.x + cos(index * PI / 6.0) * 2.1, "y": target.y + sin(index * PI / 6.0) * 2.1})
			waiting = Geo.stable_sorted(waiting, func(a, b): return Geo.distance(attacker.position, a) < Geo.distance(attacker.position, b))
			for point in waiting:
				if _is_free(attacker, point, used, is_allowed):
					selected = point
					break
		var point: Dictionary = selected.duplicate() if selected != null else attacker.position.duplicate()
		result[attacker.id] = point
		used.append(point)
	return result
