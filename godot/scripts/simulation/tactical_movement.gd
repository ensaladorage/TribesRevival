extends RefCounted
## Local deterministic steering; no rendering or random global state.
const Geo = preload("res://scripts/simulation/geometry.gd")
const Combat = preload("res://scripts/simulation/combat_rules.gd")

static func flee_goal(state: Dictionary, unit: Dictionary) -> Dictionary:
	var best: Dictionary = unit.position.duplicate()
	var best_score := -INF
	var center: Dictionary = state.totem.position
	var radius := maxf(0.0, state.totem.commandRadius - 0.15)
	var current_radius := Geo.distance(unit.position, center)
	var memory: Dictionary = unit.get("navigation", {})
	var velocity: Dictionary = memory.get("velocity", {"x": 0.0, "y": 0.0})
	for index in 33:
		var angle := TAU * float(index) / 32.0
		var length := 0.0 if index == 32 else 1.8
		var point := {"x": unit.position.x + cos(angle) * length, "y": unit.position.y + sin(angle) * length}
		var radial := Geo.distance(point, center)
		if point.x < 2 or point.y < 2 or point.x > 158 or point.y > 158 or radial < 2.02:
			continue
		if radial > radius and radial >= current_radius - 0.05:
			continue
		var safety := 10.0
		for enemy in state.barbarians:
			if enemy.isAlive:
				safety = minf(safety, Geo.distance(point, enemy.position))
		var score := minf(safety, 9.0) * 3.0
		for other in state.units:
			if other.id != unit.id:
				score -= maxf(0, 2.5 - Geo.distance(point, other.position)) * 1.5
		# Continue a chosen direction rather than alternate equivalent sides.
		var urgency := clampf((9.0 - safety) / 4.0, 0.0, 1.0)
		score += (cos(angle) * velocity.x + sin(angle) * velocity.y) * 0.06 * urgency if length > 0 else 0.12
		if current_radius > radius:
			score -= maxf(0, radial - radius) * 20.0
		if score > best_score:
			best_score = score
			best = point
	return best

static func attackers(state: Dictionary, barbarian: Dictionary) -> Array:
	var result: Array = state.units.filter(func(unit): return unit.health > 0 and unit.task.kind == "combat" and unit.task.get("targetEntityId") == barbarian.id and Combat.minion_attack(unit.role, state.toolLevels.sword) != null and Geo.distance(unit.position, barbarian.position) <= 15.0)
	result.sort_custom(func(a, b):
		var difference := Geo.distance(a.position, barbarian.position) - Geo.distance(b.position, barbarian.position)
		return a.id < b.id if absf(difference) < 1e-8 else difference < 0)
	return result

static func reposition_goal(state: Dictionary, barbarian: Dictionary, target: Dictionary, threats: Array) -> Dictionary:
	var best: Dictionary = barbarian.position.duplicate()
	var best_score := -INF
	for index in 24:
		var angle := TAU * float(index) / 24.0
		var point := {"x": barbarian.position.x + cos(angle) * 1.2, "y": barbarian.position.y + sin(angle) * 1.2}
		if point.x < 2 or point.y < 2 or point.x > 158 or point.y > 158 or Geo.distance(point, state.totem.position) < 2.02:
			continue
		var distance := Geo.distance(point, target.position)
		if distance > 3.2:
			continue
		var score := -absf(distance - 1.8)
		for threat in threats:
			if threat.id != target.id:
				score += minf(Geo.distance(point, threat.position), 4.0)
		if score > best_score:
			best_score = score
			best = point
	return best
