class_name TribeMinionMovement
extends RefCounted
## Shared movement, reservations, idle and spacing. Simulation data only.

const Geo = preload("res://scripts/simulation/geometry.gd")
const Nav = preload("res://scripts/simulation/navigation.gd")
const Idle = preload("res://scripts/simulation/minion_idle.gd")
const State = preload("res://scripts/simulation/game_state.gd")
const Combat = preload("res://scripts/simulation/combat_rules.gd")
const Random = preload("res://scripts/simulation/seeded_random.gd")
const UNIT_SPEED := 6.0
const FOLLOW_SPEED := 10.0
const RETURN_SPEED := 8.0
const FORMATION_TOLERANCE := 0.08
const TOTEM_CLEARANCE := 2.02
const FORMATION_RADIUS := 4.0
const FORMATION_SCATTER := 0.6
const FOLLOW_WANDER := 0.65

static func combat_speed(unit: Dictionary) -> float:
	var memory: Dictionary = unit.get("navigation", {})
	var fraction := clampf(float(memory.get("combatEntryRemaining", 0.0)) / 0.4, 0.0, 1.0)
	return lerpf(UNIT_SPEED, maxf(UNIT_SPEED, float(memory.get("combatEntrySpeed", UNIT_SPEED))), fraction)

static func find_entity(entities: Array, id: Variant) -> Variant:
	for entity in entities:
		if entity.id == id:
			return entity
	return null

static func area(state: Dictionary) -> Dictionary:
	return {"center": state.totem.position, "commandRadius": state.totem.commandRadius, "minimumCoordinate": 2.0, "maximumCoordinate": 158.0}

static func formation_target(state: Dictionary, index: int) -> Dictionary:
	return formation_motion(state, index).target

static func formation_motion(state: Dictionary, index: int) -> Dictionary:
	# A different, reproducible profile on each pickup. No global/random frame state.
	var unit: Dictionary = state.units[index]
	var started := int(state.totem.get("formationStartTick", 0))
	var random := Random.new("%s:formation:%s:%s" % [state.seed, unit.id, started])
	var angle := float(index) / maxi(state.units.size(), 1) * PI * 2.0
	var scatter_angle := random.next_float(0.0, TAU)
	var scatter_radius := sqrt(random.next_float()) * FORMATION_SCATTER
	var offset := Vector2.from_angle(scatter_angle) * scatter_radius
	# Independent phases and periods break the rigid ring without jitter per tick.
	var phase_x := random.next_float(0.0, TAU)
	var phase_y := random.next_float(0.0, TAU)
	var period_x := random.next_float(2.8, 4.8)
	var period_y := random.next_float(3.2, 5.2)
	var response := random.next_float(1.7, 3.2)
	var sampled_tick := int(state.tick) if state.totem.isCarried else int(state.totem.get("formationStopTick", started))
	var seconds := maxf(0.0, float(sampled_tick - started) / 20.0)
	var blend := smoothstep(0.0, 0.7, seconds)
	offset += Vector2(sin(phase_x + seconds * TAU / period_x), sin(phase_y + seconds * TAU / period_y)) * (FOLLOW_WANDER / sqrt(2.0)) * blend
	var target := {"x": state.totem.position.x + cos(angle) * FORMATION_RADIUS + offset.x, "y": state.totem.position.y + sin(angle) * FORMATION_RADIUS + offset.y}
	# Preserve the follow speed ceiling; each unit eases into its own destination.
	var minimum_speed := 0.3 if state.totem.isCarried else 6.0
	return {"target": target, "speed": minf(FOLLOW_SPEED, maxf(minimum_speed, Geo.distance(unit.position, target) * response))}

static func approach(point: Dictionary, target: Dictionary, interaction_range: float) -> Dictionary:
	var distance := Geo.distance(point, target)
	if distance <= interaction_range or distance < 0.001:
		return point.duplicate()
	var factor := interaction_range / distance
	return {"x": target.x + (point.x - target.x) * factor, "y": target.y + (point.y - target.y) * factor}

static func resource_approach(point: Dictionary, resource: Dictionary) -> Dictionary:
	var distance := Geo.distance(point, resource.position)
	var radius := maxf(resource.interactionRadius, 0.1)
	if distance < 0.001:
		return {"x": resource.position.x + radius, "y": resource.position.y}
	return {"x": resource.position.x + (point.x - resource.position.x) / distance * radius, "y": resource.position.y + (point.y - resource.position.y) / distance * radius}

static func project_within(point: Dictionary, center: Dictionary, radius: float) -> Dictionary:
	var distance := Geo.distance(point, center)
	if distance <= radius or distance < 1e-8:
		return point.duplicate()
	return State.clamp_position({"x": center.x + (point.x - center.x) / distance * radius, "y": center.y + (point.y - center.y) / distance * radius})

static func _stable_hash(value: String) -> int:
	# The PRNG constructor has not advanced, so its current state is FNV-1a.
	return Random.new(value).seed_hash()

static func outside_totem(point: Dictionary, center: Dictionary, discriminator: String = "") -> Dictionary:
	var distance := Geo.distance(point, center)
	if distance >= TOTEM_CLEARANCE:
		return point.duplicate()
	var angle := atan2(point.y - center.y, point.x - center.x) if distance > 1e-8 else (float(_stable_hash(discriminator)) / 0xffffffff) * PI * 2.0
	return State.clamp_position({"x": center.x + cos(angle) * TOTEM_CLEARANCE, "y": center.y + sin(angle) * TOTEM_CLEARANCE})

static func cancel_idle(unit: Dictionary) -> void:
	if unit.has("idleMovement"):
		unit.idleMovement.destination = null
		unit.idleMovement.waitRemainingSeconds = 0.0

static func holds_working_position(state: Dictionary, unit: Dictionary) -> bool:
	if unit.attackLockRemainingSeconds > 0:
		return true
	if unit.task.kind == "gather" and unit.state == "gathering":
		return true
	if unit.task.kind == "loot-corpse" and unit.actionProgressSeconds > 0:
		return true
	if unit.task.kind == "combat":
		var target: Variant = find_entity(state.barbarians, unit.task.get("targetEntityId"))
		var stats: Variant = Combat.minion_attack(unit.role, state.toolLevels.sword)
		var offset: Variant = unit.get("navigation", {}).get("combatOffset")
		return target != null and target.isAlive and stats != null and offset != null and Geo.distance(unit.position, {"x": target.position.x + offset.x, "y": target.position.y + offset.y}) <= 0.1 and Geo.distance(unit.position, target.position) <= stats.range
	if unit.task.kind == "hunt":
		var target: Variant = find_entity(state.animals, unit.task.get("targetEntityId"))
		return target != null and target.isAlive and Geo.distance(unit.position, target.position) <= Combat.ANIMAL_ATTACK.range
	return false

static func create_frame(state: Dictionary, delta: float) -> Dictionary:
	var origins := {}
	var followers := {}
	for unit in state.units:
		origins[unit.id] = unit.position.duplicate()
	if state.totem.isCarried or state.totem.moving:
		for index in state.units.size():
			followers[state.units[index].id] = formation_motion(state, index)
	return {"deltaSeconds": delta, "origins": origins, "followers": followers, "reservations": {}, "combatPositions": {}}

static func agent(state: Dictionary, unit: Dictionary, frame: Dictionary) -> Dictionary:
	if frame.reservations.has(unit.id):
		return frame.reservations[unit.id]
	var point: Dictionary = frame.origins.get(unit.id, unit.position)
	var destination: Variant = null
	var speed := UNIT_SPEED
	var fixed := holds_working_position(state, unit)
	if (state.totem.isCarried or (state.totem.moving and not unit.get("postCombatFree", false))) and unit.task.kind not in ["combat", "flee", "hunt"]:
		var follow: Dictionary = frame.followers[unit.id]
		destination = follow.target
		speed = follow.speed
		fixed = fixed or unit.withdrawAfterAttack
	elif unit.task.kind == "idle":
		var idle: Dictionary = unit.get("idleMovement", {})
		destination = null if idle.get("waitRemainingSeconds", 0) > 0 else idle.get("destination")
		speed = Idle.SPEED
	elif unit.task.kind == "gather":
		var resource: Variant = find_entity(state.resources, unit.task.targetResourceId)
		if resource != null:
			destination = resource_approach(point, resource)
	elif unit.task.kind == "collect-drop":
		var drop: Variant = find_entity(state.drops, unit.task.targetResourceId)
		if drop != null:
			destination = drop.position
	elif unit.task.kind == "loot-corpse":
		var corpse: Variant = find_entity(state.barbarianCorpses, unit.task.get("targetEntityId"))
		if corpse != null:
			destination = approach(point, corpse.position, 1.25)
	elif unit.task.kind in ["return-to-totem", "flee"]:
		destination = Idle.range_entry(point, area(state)) if unit.task.kind == "return-to-totem" else unit.task.get("destination", point)
		speed = RETURN_SPEED if unit.task.kind == "return-to-totem" else FOLLOW_SPEED
	elif unit.task.kind == "combat":
		var target: Variant = find_entity(state.barbarians, unit.task.get("targetEntityId"))
		if target != null and target.isAlive and Combat.minion_attack(unit.role, state.toolLevels.sword) != null:
			destination = frame.combatPositions.get(unit.id, unit.position)
			speed = combat_speed(unit)
	elif unit.task.kind == "hunt":
		var target: Variant = find_entity(state.animals, unit.task.get("targetEntityId"))
		if target != null and target.isAlive:
			destination = approach(point, target.position, Combat.ANIMAL_ATTACK.range)
	var committed: Variant = null
	var memory: Variant = unit.get("navigation")
	if destination != null and memory != null and Geo.distance(memory.goal, destination) <= 0.6 and not memory.waypoints.is_empty():
		committed = memory.waypoints[0]
	var moving_target: Variant = (committed if committed != null else destination) if not fixed else null
	return {"id": unit.id, "position": point, "fixed": fixed, "priority": 3 if fixed else (1 if unit.task.kind == "idle" else 2), "velocity": Geo.velocity_towards(point, moving_target, speed) if moving_target != null else {"x": 0, "y": 0}, "stopAfterSeconds": Geo.distance(point, moving_target) / speed if moving_target != null else 0.0, "tickVelocity": {"x": 0.0, "y": 0.0}, "waitingForClearance": memory != null and memory.blockedSeconds > 0 and Geo.length(memory.velocity) < 1e-8}

static func neighbors(state: Dictionary, unit: Dictionary, frame: Dictionary) -> Array:
	var result: Array = []
	for other in state.units:
		if other.id != unit.id:
			result.append(agent(state, other, frame))
	for other in state.barbarians:
		if other.isAlive:
			result.append({"id": other.id, "position": other.position, "velocity": {"x": 0, "y": 0}, "tickVelocity": {"x": 0, "y": 0}, "priority": 4, "fixed": true, "stopAfterSeconds": 0.0})
	return result

static func move_towards(state: Dictionary, unit: Dictionary, destination: Dictionary, distance: float, frame: Dictionary) -> bool:
	var safe := outside_totem(destination, state.totem.position, unit.id)
	var moving_agent := agent(state, unit, frame).duplicate()
	moving_agent.position = unit.position.duplicate()
	moving_agent.fixed = false
	if not unit.has("navigation"):
		unit.navigation = Nav.create_state(safe)
	var memory: Dictionary = unit.navigation
	var others := neighbors(state, unit, frame)
	var is_allowed := func(point: Dictionary) -> bool:
		if point.x < 2 or point.y < 2 or point.x > 158 or point.y > 158:
			return false
		if unit.task.kind == "flee":
			var limit := maxf(state.totem.commandRadius, Geo.distance(unit.position, state.totem.position))
			if Geo.distance(point, state.totem.position) > limit + 1e-8:
				return false
		if not state.totem.isCarried and (not state.totem.moving or unit.get("postCombatFree", false)) and unit.task.kind == "idle":
			if not Idle.within_range(point, area(state)):
				return false
			if Geo.distance(point, state.totem.position) < minf(Geo.distance(unit.position, state.totem.position), TOTEM_CLEARANCE) - 1e-8:
				return false
		return not (unit.role == "hunter" and unit.task.kind == "combat") or Geo.distance(point, state.totem.position) <= minf(state.totem.commandRadius, 10.0) + 1e-8
	if Geo.distance(memory.goal, safe) > 0.6:
		memory.waypoints = []
		memory.side = 0
		memory.replanSeconds = 0.0
	memory.goal = safe.duplicate()
	memory.replanSeconds = maxf(0, memory.replanSeconds - frame.deltaSeconds)
	memory.sideHoldSeconds = maxf(0, memory.sideHoldSeconds - frame.deltaSeconds)
	while not memory.waypoints.is_empty() and Geo.distance(unit.position, memory.waypoints[0]) < 0.08:
		memory.waypoints.pop_front()
	var obstacles: Array = others.filter(func(other): return other.fixed or memory.blockedSeconds >= 0.3)
	var next: Dictionary = memory.waypoints[0] if not memory.waypoints.is_empty() else safe
	if memory.replanSeconds <= 0 and (memory.waypoints.is_empty() or not Nav.segment_is_clear(unit.position, next, obstacles, 0.96)):
		memory.waypoints = Nav.plan_route(unit.position, safe, obstacles, is_allowed)
		memory.replanSeconds = 0.6
	if memory.waypoints.size() == 1:
		memory.waypoints[0] = safe.duplicate()
	var waypoint: Dictionary = memory.waypoints[0] if not memory.waypoints.is_empty() else safe
	var unavailable: bool = memory.waypoints.is_empty() and not Nav.segment_is_clear(unit.position, safe, obstacles)
	var result: Dictionary
	if unavailable:
		result = {"position": unit.position.duplicate(), "velocity": {"x": 0.0, "y": 0.0}, "blocked": true}
	else:
		result = Nav.choose_step({"agent": moving_agent, "destination": waypoint, "speed": distance / maxf(frame.deltaSeconds, 1e-8), "deltaSeconds": frame.deltaSeconds, "neighbors": others, "previousVelocity": memory.velocity, "preferredSide": memory.side}, is_allowed)
	var forward := Geo.velocity_towards(unit.position, waypoint, 1)
	var turn: float = forward.x * result.velocity.y - forward.y * result.velocity.x
	if absf(turn) > 1e-6:
		if memory.side == 0:
			memory.side = signf(turn)
		memory.sideHoldSeconds = 0.6
	if memory.sideHoldSeconds <= 0 and not result.blocked:
		memory.side = 0
	memory.velocity = result.velocity
	memory.blockedSeconds = memory.blockedSeconds + frame.deltaSeconds if result.blocked else 0.0
	if memory.blockedSeconds >= 0.3 and memory.replanSeconds <= 0:
		memory.waypoints = Nav.plan_route(unit.position, safe, others, is_allowed)
		memory.side = 0
		memory.replanSeconds = 0.6
	unit.position.merge(result.position, true)
	var origin: Dictionary = frame.origins.get(unit.id, moving_agent.position)
	var reservation := moving_agent.duplicate()
	reservation.position = origin
	reservation.velocity = result.velocity
	reservation.stopAfterSeconds = Geo.distance(origin, waypoint) / maxf(Geo.length(result.velocity), 1e-8)
	reservation.tickVelocity = {"x": (unit.position.x - origin.x) / frame.deltaSeconds, "y": (unit.position.y - origin.y) / frame.deltaSeconds}
	frame.reservations[unit.id] = reservation
	if memory.blockedSeconds >= 1.2 and unit.task.kind == "idle":
		cancel_idle(unit)
	return Geo.distance(unit.position, safe) <= FORMATION_TOLERANCE

static func update_idle(state: Dictionary, unit: Dictionary, delta: float, frame: Dictionary) -> void:
	if not unit.has("idleMovement"):
		unit.idleMovement = {"destination": null, "waitRemainingSeconds": 0.0, "step": 0}
	var idle: Dictionary = unit.idleMovement
	if idle.destination == null and idle.waitRemainingSeconds <= 0:
		idle.waitRemainingSeconds = Idle.wait_seconds(state.seed, unit.id, idle.step)
		var idle_neighbors: Array = []
		var ordered: Array = state.units.duplicate()
		ordered.sort_custom(func(a, b): return a.id < b.id)
		for other in ordered:
			if other.id != unit.id:
				idle_neighbors.append({"position": other.position, "destination": other.get("idleMovement", {}).get("destination", null) if other.task.kind != "return-to-totem" else other.task.destination})
		idle.destination = Idle.choose_destination(state.seed, unit.id, idle.step, unit.position, area(state), idle_neighbors)
		idle.step += 1
	unit.state = "idle"
	if idle.waitRemainingSeconds > 0:
		idle.waitRemainingSeconds = maxf(0, idle.waitRemainingSeconds - delta)
		var allowed := func(point: Dictionary) -> bool:
			return point.x >= 2 and point.y >= 2 and point.x <= 158 and point.y <= 158 and Idle.within_range(point, area(state)) and Geo.distance(point, state.totem.position) >= minf(Geo.distance(unit.position, state.totem.position), TOTEM_CLEARANCE) - 1e-8
		var target: Variant = Nav.idle_yield_target(agent(state, unit, frame), neighbors(state, unit, frame), allowed)
		if target != null:
			move_towards(state, unit, target, Idle.SPEED * delta, frame)
		return
	if idle.destination != null and move_towards(state, unit, idle.destination, Idle.SPEED * delta, frame):
		idle.destination = null

static func _separate_pair(first: Dictionary, second: Dictionary, minimum: float, seed_text: String, first_share: float = 0.5) -> void:
	var dx: float = second.x - first.x
	var dy: float = second.y - first.y
	var distance := sqrt(dx * dx + dy * dy)
	if distance >= minimum:
		return
	if distance < 1e-8:
		var angle := float(_stable_hash(seed_text)) / 0xffffffff * PI * 2.0
		dx = cos(angle)
		dy = sin(angle)
		distance = 0.0
	var adjustment := minimum - distance
	var nx := dx / distance if distance > 0 else dx
	var ny := dy / distance if distance > 0 else dy
	first.x -= nx * adjustment * first_share
	first.y -= ny * adjustment * first_share
	second.x += nx * adjustment * (1.0 - first_share)
	second.y += ny * adjustment * (1.0 - first_share)

static func _constrain(state: Dictionary, unit: Dictionary, flee_limits: Dictionary) -> void:
	if unit.task.kind == "flee":
		unit.position.merge(project_within(State.clamp_position(unit.position), state.totem.position, flee_limits[unit.id]), true)
	if unit.role == "hunter" and unit.task.kind == "combat":
		unit.position.merge(project_within(unit.position, state.totem.position, minf(state.totem.commandRadius, 10)), true)
	if not state.totem.isCarried and (not state.totem.moving or unit.get("postCombatFree", false)) and unit.task.kind == "idle" and unit.get("idleMovement", {}).get("destination") != null:
		unit.position.merge(project_within(unit.position, state.totem.position, state.totem.commandRadius), true)
		unit.position.merge(State.clamp_position(outside_totem(unit.position, state.totem.position, unit.id)), true)

static func resolve_spacing(state: Dictionary) -> void:
	# If a moved totem leaves a civilian outside, allow gradual return without
	# an artificial snap. Spacing may never push it farther out this tick.
	var flee_limits := {}
	for unit in state.units:
		if unit.task.kind == "flee":
			flee_limits[unit.id] = maxf(state.totem.commandRadius, Geo.distance(unit.position, state.totem.position))
	var units: Array = state.units.duplicate()
	units.sort_custom(func(a, b): return a.id < b.id)
	var barbarians: Array = state.barbarians.filter(func(barbarian): return barbarian.isAlive)
	barbarians.sort_custom(func(a, b): return a.id < b.id)
	for unit in units:
		_constrain(state, unit, flee_limits)
	for pass_index in 8:
		for first_index in units.size():
			var first: Dictionary = units[first_index]
			for second_index in range(first_index + 1, units.size()):
				var second: Dictionary = units[second_index]
				var first_fixed := holds_working_position(state, first)
				var second_fixed := holds_working_position(state, second)
				var first_share := 0.0 if first_fixed and not second_fixed else (1.0 if second_fixed and not first_fixed else 0.5)
				_separate_pair(first.position, second.position, Nav.MINIMUM_SEPARATION, first.id + ":" + second.id, first_share)
				_constrain(state, first, flee_limits)
				_constrain(state, second, flee_limits)
			for barbarian in barbarians:
				_separate_pair(first.position, barbarian.position, Nav.MINIMUM_SEPARATION, first.id + ":" + barbarian.id, 1.0)
				_constrain(state, first, flee_limits)
		for first_index in barbarians.size():
			for second_index in range(first_index + 1, barbarians.size()):
				_separate_pair(barbarians[first_index].position, barbarians[second_index].position, Nav.MINIMUM_SEPARATION, barbarians[first_index].id + ":" + barbarians[second_index].id)
	for unit in units:
		_constrain(state, unit, flee_limits)
