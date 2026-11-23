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

static func can_pick_up(state: Dictionary, unit: Variant) -> bool:
	return unit != null and unit.health > 0 and not Work.blocks_combat_pickup(unit.role, unit.task.kind) and int(unit.get("pickupLockTicks", 0)) <= 0 and not state.totem.isCarried and held_unit(state) == null

static func pick_up(state: Dictionary, unit_id: String) -> bool:
	var unit: Variant = Move.find_entity(state.units, unit_id)
	if not can_pick_up(state, unit):
		return false
	Work.set_task(unit, Rules.idle_task("minion-picked-up"))
	Move.cancel_idle(unit)
	unit.erase("navigation")
	unit.erase("postCombatFree")
	unit.lastLanding = unit.position.duplicate()
	unit.isCarried = true
	unit.state = "carried"
	# Cancel the draw when picked up. Released arrows resolve independently.
	if state.has("hunterShots"):
		var remaining: Array = state.hunterShots.filter(func(shot): return shot.hunterId != unit_id or shot.has("origin"))
		if remaining.is_empty():
			state.erase("hunterShots")
		else:
			state.hunterShots = remaining
	# The hit was already resolved; remove only its remaining visual feedback.
	state.effects = state.effects.filter(func(effect): return effect.targetId != unit_id or effect.kind not in ["attack-lunge", "heal-crosses"])
	state.alerts = state.alerts.filter(func(alert): return alert.detectorKind != "minion" or alert.detectorId != unit_id)
	return true

static func drag(state: Dictionary, unit_id: String, point: Dictionary, surface_valid: bool = true) -> void:
	var unit: Variant = held_unit(state)
	if unit != null and unit.id == unit_id:
		unit.position = State.clamp_position(point)
		if surface_valid and Move.Terrain.fits(state.get("terrain",[]),unit.position,0.32,true):
			unit.lastLanding = unit.position.duplicate()

static func drop(state: Dictionary, unit_id: String, within_command: bool = false) -> void:
	var unit: Variant = held_unit(state)
	if unit == null or unit.id != unit_id:
		return
	unit.position = drop_position(state, unit, unit.get("lastLanding",unit.position), within_command)
	unit.erase("lastLanding")
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

# World positions in Vector2 are single precision. A projected boundary at
# 158 metres can round inward by several micrometres on each axis.
const DROP_CLEARANCE_EPSILON := 0.00003

static func _allowed(point: Vector2, circles: Array, rows: Array) -> bool:
	if not Move.Terrain.fits(rows,{"x":point.x,"y":point.y},0.32,true):
		return false
	if point.x < 2.0 - 1e-7 or point.y < 2.0 - 1e-7 or point.x > 158.0 + 1e-7 or point.y > 158.0 + 1e-7:
		return false
	for circle in circles:
		var distance: float = point.distance_to(circle.center)
		if circle.get("outer", false):
			if distance > circle.radius + DROP_CLEARANCE_EPSILON:
				return false
		elif distance < circle.radius - DROP_CLEARANCE_EPSILON:
			return false
	return true

static func drop_position(state: Dictionary, unit: Dictionary, requested: Dictionary, within_command: bool = false) -> Dictionary:
	var point := _point(State.clamp_position(requested))
	var circles: Array = [{"center": _point(state.totem.position), "radius": Move.TOTEM_CLEARANCE}]
	for other in state.units + state.barbarians + state.animals:
		if other.id != unit.id and other.get("isAlive", true) and not other.get("isCarried", false):
			circles.append({"center": _point(other.position), "radius": Move.Nav.MINIMUM_SEPARATION})
	if within_command:
		# Include intersections with the command boundary when its nearest point is occupied.
		circles.append({"center": _point(state.totem.position), "radius": state.totem.commandRadius - 2 * DROP_CLEARANCE_EPSILON, "outer": true})
	if _allowed(point, circles, state.get("terrain",[])):
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
	var best := point
	var best_distance := INF
	for candidate in candidates:
		if not _allowed(candidate, circles, state.get("terrain",[])):
			continue
		var distance := point.distance_squared_to(candidate)
		if distance < best_distance - 1e-8 or (absf(distance - best_distance) <= 1e-8 and (candidate.x < best.x or (candidate.x == best.x and candidate.y < best.y))):
			best = candidate
			best_distance = distance
	# In a dense overlap, confirm there is no nearby gap before accepting a
	# distant intersection or map corner. Search outward from the cursor.
	if (not within_command or best_distance == INF) and best_distance > pow(Move.TOTEM_CLEARANCE + 0.01, 2):
		var radius := Move.Nav.MINIMUM_SEPARATION
		while radius <= State.WORLD_SIZE and radius * radius < best_distance:
			for step in 32:
				var nearby := point + Vector2.from_angle(TAU * step / 32.0) * radius
				if _allowed(nearby, circles, state.get("terrain",[])):
					return State.clamp_position({"x": nearby.x, "y": nearby.y})
			radius += 0.25
	return State.clamp_position({"x": best.x, "y": best.y})
