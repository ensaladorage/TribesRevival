extends RefCounted
## Local deterministic steering; no rendering or random global state.
const Geo = preload("res://scripts/simulation/geometry.gd")
const Combat = preload("res://scripts/simulation/combat_rules.gd")

const Move = preload("res://scripts/simulation/minion_movement.gd")
const Nav = preload("res://scripts/simulation/navigation.gd")
const Random = preload("res://scripts/simulation/seeded_random.gd")
const FLEE_DIRECTIONS := 32
const FLEE_SPEED := 10.0
const PAUSE_MIN_SECONDS := 2.0
const PAUSE_MAX_SECONDS := 4.0
const DODGE_DISTANCE := 8.0
const DODGE_SECONDS := 1.6
const BLOCKED_SECONDS := 1.0
const GOAL_MARGIN := 0.15
const FOLLOW_ENTRY_MARGIN := 1.0
const COMBAT_AREA_RADIUS := 3.0

static func combat_area_clear(state: Dictionary, point: Dictionary) -> bool:
	for enemy in state.barbarians:
		if not enemy.isAlive or Geo.distance(point, enemy.position) >= COMBAT_AREA_RADIUS:
			continue
		if not Move.Terrain.same_level(state.get("terrain", []), point, enemy.position):
			continue
		var target: Variant = Move.find_entity(state.units, enemy.targetUnitId)
		if target != null and Combat.minion_attack(target.role, state.toolLevels.sword) != null:
			return false
	return true

static func avoid_combat_goal(state: Dictionary, unit: Dictionary) -> Dictionary:
	if unit.task.kind == "avoid-combat" and combat_area_clear(state, unit.task.destination) and Move.flee_point_allowed(state, unit, unit.task.destination):
		return unit.task.destination
	var best: Dictionary = unit.position.duplicate()
	var best_length := INF
	var obstacles: Array = state.barbarians.filter(func(enemy): return enemy.isAlive)
	for radius in [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]:
		for index in FLEE_DIRECTIONS:
			var angle := TAU * index / FLEE_DIRECTIONS
			var point := {"x": unit.position.x + cos(angle) * radius, "y": unit.position.y + sin(angle) * radius}
			if not combat_area_clear(state, point) or not Move.flee_point_allowed(state, unit, point) or Geo.distance(point, state.totem.position) < Move.TOTEM_CLEARANCE:
				continue
			var route := Nav.plan_route(unit.position, point, obstacles, func(candidate): return Move.flee_point_allowed(state, unit, candidate))
			if route.is_empty(): continue
			var length := 0.0
			var previous: Dictionary = unit.position
			for waypoint in route:
				length += Geo.distance(previous, waypoint)
				previous = waypoint
			if length < best_length - 1e-8:
				best = point
				best_length = length
		if best_length < INF: break
	return best

static func _follow_entry(state: Dictionary, unit: Dictionary) -> Dictionary:
	var center: Dictionary = state.totem.position
	var angle := atan2(unit.position.y - center.y, unit.position.x - center.x)
	var radius := maxf(0.0, state.totem.commandRadius - FOLLOW_ENTRY_MARGIN)
	var bodies: Array = state.units.filter(func(other): return other.id != unit.id and not other.get("isCarried", false))
	bodies.append_array(state.barbarians.filter(func(enemy): return enemy.isAlive))
	# Do not aim at a paused ally on the command boundary. A clear inset goal
	# lets shared navigation find a route through/around the waiting group.
	for offset in [0, 1, -1, 2, -2, 3, -3, 4, -4]:
		var candidate_angle: float = angle + offset * PI / 12.0
		var point := {"x": center.x + cos(candidate_angle) * radius, "y": center.y + sin(candidate_angle) * radius}
		if not Move.flee_point_allowed(state, unit, point): continue
		if bodies.any(func(body): return Geo.distance(body.position, point) < 0.96): continue
		return point
	return Move.Idle.range_entry(unit.position, Move.area(state))

static func _safety(state: Dictionary, point: Dictionary) -> float:
	var safety := INF
	for enemy in state.barbarians:
		if enemy.isAlive:
			safety = minf(safety, Geo.distance(point, enemy.position))
	return safety

static func _choose_flee_goal(state: Dictionary, unit: Dictionary, local: bool) -> Dictionary:
	var memory: Dictionary = unit.fleeMemory
	var random := Random.new("%s:flee-goal:%s:%s:%s" % [state.seed, unit.id, int(memory.get("startedTick", 0)), int(memory.cycle)])
	var obstacles: Array = state.barbarians.filter(func(enemy): return enemy.isAlive)
	obstacles.append_array(state.units.filter(func(other): return other.id != unit.id and Move.holds_working_position(state, other)))
	obstacles.append(Move.flee_totem_obstacle(state))
	var center: Dictionary = state.totem.position
	var outer := maxf(0.0, state.totem.commandRadius - GOAL_MARGIN)
	var inner := minf(4.0, outer)
	for index in FLEE_DIRECTIONS:
		var angle := random.next_float(0.0, TAU)
		var radius := sqrt(random.next_float(inner * inner, outer * outer))
		var point := {"x": center.x + cos(angle) * radius, "y": center.y + sin(angle) * radius}
		var distance := Geo.distance(unit.position, point)
		if distance < 3.0 or (local and distance > DODGE_DISTANCE): continue
		if not Move.flee_point_allowed(state, unit, point): continue
		var route := Nav.plan_route(unit.position, point, obstacles, func(candidate): return Move.flee_point_allowed(state, unit, candidate))
		if not route.is_empty(): return point
	return unit.position.duplicate()

static func prepare_flee(state: Dictionary, unit: Dictionary) -> void:
	if not unit.has("fleeMemory"):
		unit.fleeMemory = {"startedTick": state.tick, "phase": "escape", "goal": unit.position.duplicate(), "anchor": null, "pauseRemaining": 0.0, "dodgeRemaining": 0.0, "distanceTravelled": 0.0, "blockedSeconds": 0.0, "cycle": 0, "suspended": false}
		if Geo.distance(unit.position, state.totem.position) <= state.totem.commandRadius:
			unit.fleeMemory.goal = _choose_flee_goal(state, unit, false)
	var memory: Dictionary = unit.fleeMemory
	var outside: bool = Geo.distance(unit.position, state.totem.position) > state.totem.commandRadius + 1e-8
	if outside:
		memory.suspended = true
		unit.task.destination = _follow_entry(state, unit)
		unit.state = "follow-totem" if state.totem.isCarried or state.totem.moving else "returning-to-totem"
		return
	if memory.suspended:
		memory.suspended = false
		if memory.anchor == null or not Move.flee_point_allowed(state, unit, memory.anchor):
			memory.anchor = unit.position.duplicate()
		if memory.phase != "pause":
			_start_pause(state, unit)
		memory.goal = unit.position.duplicate()
		unit.erase("navigation")
	elif not Move.flee_point_allowed(state, unit, memory.goal):
		# A moving command area may invalidate a goal without leaving the unit out.
		# End the run locally, rather than granting another full escape.
		memory.anchor = unit.position.duplicate()
		if memory.phase != "pause":
			_start_pause(state, unit)
		memory.goal = unit.position.duplicate()
	unit.task.destination = unit.position.duplicate() if memory.phase == "pause" else memory.goal.duplicate()

static func _start_pause(state: Dictionary, unit: Dictionary) -> void:
	var memory: Dictionary = unit.fleeMemory
	memory.phase = "pause"
	memory.goal = unit.position.duplicate()
	# JSON reads numeric counters as floats; seed text must remain identical.
	memory.pauseRemaining = Random.new("%s:flee:%s:%s" % [state.seed, unit.id, int(memory.cycle)]).next_float(PAUSE_MIN_SECONDS, PAUSE_MAX_SECONDS)
	memory.cycle += 1
	memory.dodgeRemaining = 0.0
	memory.distanceTravelled = 0.0
	memory.blockedSeconds = 0.0
	unit.task.destination = unit.position.duplicate()
	unit.erase("navigation")

static func update_flee(state: Dictionary, unit: Dictionary, delta: float, frame: Dictionary) -> void:
	var memory: Dictionary = unit.fleeMemory
	if memory.suspended:
		Move.move_towards(state, unit, unit.task.destination, FLEE_SPEED * delta, frame)
		return
	if memory.phase == "pause":
		Move.hold_position(state, unit, frame)
		memory.pauseRemaining = maxf(0.0, memory.pauseRemaining - delta)
		if memory.pauseRemaining <= 1e-9:
			var goal := _choose_flee_goal(state, unit, true)
			if Geo.distance(goal, unit.position) <= Move.FORMATION_TOLERANCE:
				_start_pause(state, unit)
			else:
				memory.phase = "dodge"
				memory.goal = goal
				memory.dodgeRemaining = DODGE_SECONDS
				memory.distanceTravelled = 0.0
				unit.task.destination = goal.duplicate()
		return
	var before: Dictionary = unit.position.duplicate()
	var budget := FLEE_SPEED * delta
	if memory.phase == "dodge":
		budget = minf(budget, minf(DODGE_DISTANCE - memory.distanceTravelled, FLEE_SPEED * memory.dodgeRemaining))
	var arrived := Move.move_towards(state, unit, memory.goal, maxf(0.0, budget), frame)
	var travelled := Geo.distance(before, unit.position)
	if memory.phase == "escape":
		memory.blockedSeconds = memory.blockedSeconds + delta if travelled < 0.01 else 0.0
		if arrived or memory.blockedSeconds + 1e-9 >= BLOCKED_SECONDS:
			memory.anchor = unit.position.duplicate()
			_start_pause(state, unit)
	else:
		memory.distanceTravelled += travelled
		memory.dodgeRemaining = maxf(0.0, memory.dodgeRemaining - delta)
		if arrived or memory.distanceTravelled + 1e-8 >= DODGE_DISTANCE or memory.dodgeRemaining <= 1e-9:
			_start_pause(state, unit)

static func attackers(state: Dictionary, barbarian: Dictionary) -> Array:
	var result: Array = state.units.filter(func(unit): return unit.health > 0 and not unit.get("isCarried", false) and unit.task.kind == "combat" and unit.task.get("targetEntityId") == barbarian.id and Combat.minion_attack(unit.role, state.toolLevels.sword) != null and Geo.distance(unit.position, barbarian.position) <= 15.0)
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
