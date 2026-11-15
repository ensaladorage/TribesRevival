extends RefCounted
## Manual repositioning. Only optional, serializable data lives on the unit.

const Move = preload("res://scripts/simulation/minion_movement.gd")
const Work = preload("res://scripts/simulation/work_system.gd")
const Rules = preload("res://scripts/simulation/survival_rules.gd")
const State = preload("res://scripts/simulation/game_state.gd")

static func held_unit(state: Dictionary) -> Variant:
	for unit in state.units:
		if unit.get("isCarried", false):
			return unit
	return null

static func pick_up(state: Dictionary, unit_id: String) -> void:
	if state.totem.isCarried or held_unit(state) != null:
		return
	var unit: Variant = Move.find_entity(state.units, unit_id)
	if unit == null or unit.health <= 0:
		return
	Work.set_task(unit, Rules.idle_task("minion-picked-up"))
	Move.cancel_idle(unit)
	unit.erase("navigation")
	unit.erase("postCombatFree")
	unit.isCarried = true
	unit.state = "carried"
	# The hit was already resolved; remove only its remaining visual feedback.
	state.effects = state.effects.filter(func(effect): return effect.targetId != unit_id or effect.kind not in ["attack-lunge", "heal-crosses"])
	state.alerts = state.alerts.filter(func(alert): return alert.detectorKind != "minion" or alert.detectorId != unit_id)

static func drag(state: Dictionary, unit_id: String, point: Dictionary) -> void:
	var unit: Variant = held_unit(state)
	if unit != null and unit.id == unit_id:
		unit.position = State.clamp_position(point)

static func drop(state: Dictionary, unit_id: String) -> void:
	var unit: Variant = held_unit(state)
	if unit == null or unit.id != unit_id:
		return
	unit.position = drop_position(state, unit, unit.position)
	unit.erase("isCarried")
	Work.set_task(unit, Rules.idle_task("minion-dropped") if Move.Idle.within_range(unit.position, Move.area(state)) else Work.return_task(state, unit, "minion-dropped"))
	# Do not force an old formation slot after a manual placement.
	unit.postCombatFree = true

static func drop_all(state: Dictionary) -> void:
	for unit in state.units:
		if unit.get("isCarried", false):
			drop(state, unit.id)

static func _point(point: Dictionary) -> Vector2:
	return Vector2(point.x, point.y)

static func _allowed(point: Vector2, circles: Array) -> bool:
	if point.x < 2.0 - 1e-7 or point.y < 2.0 - 1e-7 or point.x > 158.0 + 1e-7 or point.y > 158.0 + 1e-7:
		return false
	for circle in circles:
		if point.distance_to(circle.center) < circle.radius - 1e-7:
			return false
	return true

static func drop_position(state: Dictionary, unit: Dictionary, requested: Dictionary) -> Dictionary:
	var point := _point(State.clamp_position(requested))
	var circles: Array = [{"center": _point(state.totem.position), "radius": Move.TOTEM_CLEARANCE}]
	for other in state.units + state.barbarians + state.animals:
		if other.id != unit.id and other.get("isAlive", true) and not other.get("isCarried", false):
			circles.append({"center": _point(other.position), "radius": Move.Nav.MINIMUM_SEPARATION})
	if _allowed(point, circles):
		return {"x": point.x, "y": point.y}
	# The closest free point lies on a circle/edge, or their intersections.
	# Enumerating these candidates avoids frame-dependent iterative pushing.
	var candidates: Array[Vector2] = [Vector2(2, 2), Vector2(2, 158), Vector2(158, 2), Vector2(158, 158)]
	for index in circles.size():
		var circle: Dictionary = circles[index]
		var center: Vector2 = circle.center
		var radius: float = circle.radius
		var direction := (point - center).normalized() if point != center else Vector2.RIGHT
		candidates.append(center + direction * radius)
		for edge in [2.0, 158.0]:
			for axis in 2:
				var offset: float = edge - center[axis]
				if absf(offset) > radius:
					continue
				var length := sqrt(maxf(0.0, radius * radius - offset * offset))
				for sign_value in [-1.0, 1.0]:
					var candidate := center
					candidate[axis] = edge
					candidate[1 - axis] += sign_value * length
					candidates.append(candidate)
		for other_index in range(index + 1, circles.size()):
			var other: Dictionary = circles[other_index]
			var difference: Vector2 = other.center - center
			var distance := difference.length()
			if distance < 1e-8 or distance > radius + other.radius or distance < absf(radius - other.radius):
				continue
			var along: float = (radius * radius - other.radius * other.radius + distance * distance) / (2.0 * distance)
			var normal := difference / distance
			var middle := center + normal * along
			var height := sqrt(maxf(0.0, radius * radius - along * along))
			candidates.append(middle + normal.orthogonal() * height)
			candidates.append(middle - normal.orthogonal() * height)
	var best := Vector2(2, 2)
	var best_distance := INF
	for candidate in candidates:
		if not _allowed(candidate, circles):
			continue
		var distance := point.distance_squared_to(candidate)
		if distance < best_distance - 1e-8 or (absf(distance - best_distance) <= 1e-8 and (candidate.x < best.x or (candidate.x == best.x and candidate.y < best.y))):
			best = candidate
			best_distance = distance
	return State.clamp_position({"x": best.x, "y": best.y})
