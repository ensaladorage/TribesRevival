class_name TribeMinionIdle
extends RefCounted

const Geo = preload("res://scripts/simulation/geometry.gd")
const Random = preload("res://scripts/simulation/seeded_random.gd")
const INNER_RADIUS := 4.0
const OUTER_RADIUS := 8.0
const SPEED := 3.0

static func within_range(point: Dictionary, area: Dictionary) -> bool:
	return Geo.distance(point, area.center) <= maxf(0, area.commandRadius) + 1e-8

static func range_entry(point: Dictionary, area: Dictionary) -> Dictionary:
	var dx: float = point.x - area.center.x
	var dy: float = point.y - area.center.y
	var distance := sqrt(dx * dx + dy * dy)
	var scale := minf(1, maxf(0, area.commandRadius) / distance) if distance > 0 else 0.0
	return {"x": clampf(area.center.x + dx * scale, area.minimumCoordinate, area.maximumCoordinate), "y": clampf(area.center.y + dy * scale, area.minimumCoordinate, area.maximumCoordinate)}

static func wait_seconds(seed_text: String, id: String, step: int) -> float:
	return Random.new("%s:%s:idle-wait:%s" % [seed_text, id, step]).next_float(1, 3)

static func destination_score(point: Dictionary, center: Dictionary, neighbors: Array) -> float:
	var dx: float = point.x - center.x
	var dy: float = point.y - center.y
	var distance := sqrt(dx * dx + dy * dy)
	if distance == 0:
		distance = 1.0
	var behind := maxf(0, -(dx * sin(PI / 4) + dy * cos(PI / 4)) / distance)
	var crowd := 0.0
	for other in neighbors:
		var proximity := maxf(0, 1.0 - Geo.distance(point, other.position) / 1.5)
		var destination: Variant = other.get("destination")
		if destination != null:
			proximity = maxf(proximity, maxf(0, 1.0 - Geo.distance(point, destination) / 1.5))
		crowd += proximity
	return behind + 2.0 * crowd

static func _inside_world(point: Dictionary, area: Dictionary) -> bool:
	return point.x >= area.minimumCoordinate and point.x <= area.maximumCoordinate and point.y >= area.minimumCoordinate and point.y <= area.maximumCoordinate

static func choose_destination(seed_text: String, id: String, step: int, point: Dictionary, area: Dictionary, neighbors: Array = []) -> Dictionary:
	var random := Random.new("%s:%s:idle-destination:%s" % [seed_text, id, step])
	var outer := maxf(0, minf(OUTER_RADIUS, area.commandRadius))
	var inner := minf(INNER_RADIUS, outer)
	var dx: float = point.x - area.center.x
	var dy: float = point.y - area.center.y
	var distance := sqrt(dx * dx + dy * dy)
	var angle := atan2(dy, dx) if distance > 1e-8 else random.next_float(0, TAU)
	var best: Dictionary = {}
	var best_score := INF
	for attempt in 24:
		var radius := random.next_float(inner, outer)
		var safe_angle := 0.0
		if distance >= inner and outer != 0:
			safe_angle = minf(PI / 3, acos(minf(inner / maxf(distance, 1e-8), 1)) + acos(minf(inner / maxf(radius, 1e-8), 1))) * 0.95
		var candidate_angle := angle + random.next_float(-safe_angle, safe_angle)
		var candidate := {"x": area.center.x + cos(candidate_angle) * radius, "y": area.center.y + sin(candidate_angle) * radius}
		if _inside_world(candidate, area) and Geo.distance(candidate, point) > 0.25:
			var score := destination_score(candidate, area.center, neighbors)
			if score < best_score - 1e-8:
				best_score = score
				best = candidate
	if not best.is_empty():
		return best
	if _inside_world(point, area) and distance >= inner and distance <= outer:
		return point.duplicate()
	return range_entry(point, area)
