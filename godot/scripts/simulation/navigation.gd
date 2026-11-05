class_name TribeNavigation
extends RefCounted
## Pure visibility graph and continuous actor avoidance from minionNavigation.ts.

const Geo = preload("res://scripts/simulation/geometry.gd")
const MINIMUM_SEPARATION := 0.94
const PREDICTION_SECONDS := 0.6
const ANGLES := [0, 25, -25, 50, -50, 75, -75]

static func create_state(goal: Dictionary) -> Dictionary:
	return {"goal": goal.duplicate(), "waypoints": [], "velocity": {"x": 0.0, "y": 0.0}, "side": 0, "sideHoldSeconds": 0.0, "blockedSeconds": 0.0, "replanSeconds": 0.0, "combatTargetId": null, "combatOffset": null}

static func closest_approach(first: Dictionary, second: Dictionary, horizon: float) -> float:
	var cuts: Array = [0.0, minf(first.stopAfterSeconds, horizon), minf(second.stopAfterSeconds, horizon), horizon]
	cuts.sort()
	var minimum := Geo.distance(first.position, second.position)
	for index in range(1, cuts.size()):
		var start: float = cuts[index - 1]
		var segment_length: float = cuts[index] - start
		var a := Geo.at(first.position, first.velocity, minf(start, first.stopAfterSeconds))
		var b := Geo.at(second.position, second.velocity, minf(start, second.stopAfterSeconds))
		var vx: float = (first.velocity.x if start < first.stopAfterSeconds else 0.0) - (second.velocity.x if start < second.stopAfterSeconds else 0.0)
		var vy: float = (first.velocity.y if start < first.stopAfterSeconds else 0.0) - (second.velocity.y if start < second.stopAfterSeconds else 0.0)
		var dx: float = a.x - b.x
		var dy: float = a.y - b.y
		var denominator := vx * vx + vy * vy
		var time := clampf(-(dx * vx + dy * vy) / (denominator if denominator != 0 else 1.0), 0.0, segment_length)
		minimum = minf(minimum, sqrt(pow(dx + vx * time, 2) + pow(dy + vy * time, 2)))
	return minimum

static func segment_is_clear(start: Dictionary, end: Dictionary, obstacles: Array, clearance: float = 0.96) -> bool:
	var velocity := Geo.velocity_towards(start, end, Geo.distance(start, end))
	var first := {"position": start, "velocity": velocity, "stopAfterSeconds": 1.0}
	for obstacle in obstacles:
		var second := {"position": obstacle.position, "velocity": {"x": 0, "y": 0}, "stopAfterSeconds": 0.0}
		if closest_approach(first, second, 1.0) < minf(clearance, Geo.distance(start, obstacle.position)) - 1e-7:
			return false
	return true

static func _edge_allowed(first: Dictionary, second: Dictionary, obstacles: Array, is_allowed: Callable) -> bool:
	if not segment_is_clear(first, second, obstacles):
		return false
	var samples := maxi(1, int(ceil(Geo.distance(first, second) / 0.4)))
	for step in range(1, samples + 1):
		if not is_allowed.call({"x": first.x + (second.x - first.x) * step / samples, "y": first.y + (second.y - first.y) * step / samples}):
			return false
	return true

static func plan_route(start: Dictionary, goal: Dictionary, obstacles: Array, is_allowed: Callable) -> Array:
	var ordered := obstacles.duplicate()
	ordered.sort_custom(func(a, b): return a.id < b.id)
	if _edge_allowed(start, goal, ordered, is_allowed):
		return [goal.duplicate()]
	var points: Array = [start, goal]
	for obstacle in ordered:
		for index in 12:
			var angle := index * PI / 6.0
			var point := {"x": obstacle.position.x + cos(angle) * 1.2, "y": obstacle.position.y + sin(angle) * 1.2}
			var valid: bool = is_allowed.call(point)
			for other in ordered:
				if Geo.distance(point, other.position) < 1.02:
					valid = false
			if valid:
				points.append(point)
	var costs: Array = []
	var previous: Array = []
	var visited := {}
	costs.resize(points.size())
	costs.fill(INF)
	previous.resize(points.size())
	previous.fill(-1)
	costs[0] = 0.0
	while visited.size() < points.size():
		var current := -1
		for index in points.size():
			if not visited.has(index) and (current < 0 or costs[index] < costs[current] - 1e-7):
				current = index
		if current < 0 or not is_finite(costs[current]):
			break
		if current == 1:
			var path: Array = []
			var path_index := 1
			while path_index != 0:
				path.push_front(points[path_index].duplicate())
				path_index = previous[path_index]
			return path
		visited[current] = true
		for index in range(1, points.size()):
			if visited.has(index):
				continue
			var cost: float = costs[current] + Geo.distance(points[index], points[current])
			if cost < costs[index] - 1e-7 and _edge_allowed(points[current], points[index], ordered, is_allowed):
				costs[index] = cost
				previous[index] = current
	return []

static func gives_way_to(agent: Dictionary, other: Dictionary) -> bool:
	return other.fixed or other.priority > agent.priority or (other.priority == agent.priority and other.id < agent.id)

static func _separation_is_safe(agent: Dictionary, other: Dictionary, horizon: float) -> bool:
	var initial := Geo.distance(agent.position, other.position)
	var required := minf(MINIMUM_SEPARATION, initial)
	if closest_approach(agent, other, horizon) < required - 1e-7:
		return false
	if initial < MINIMUM_SEPARATION - 1e-7:
		var end := Geo.at(agent.position, agent.velocity, minf(horizon, agent.stopAfterSeconds))
		var other_end := Geo.at(other.position, other.velocity, minf(horizon, other.stopAfterSeconds))
		return Geo.distance(end, other_end) > initial + 1e-7
	return true

static func choose_step(input: Dictionary, is_allowed: Callable) -> Dictionary:
	var agent: Dictionary = input.agent
	var destination: Dictionary = input.destination
	var speed: float = input.speed
	var delta: float = input.deltaSeconds
	var neighbors: Array = input.neighbors.duplicate()
	neighbors.sort_custom(func(a, b): return a.id < b.id)
	var distance := Geo.distance(destination, agent.position)
	var forward := Geo.velocity_towards(agent.position, destination, 1.0)
	for fraction in [1.0, 0.5]:
		var best: Dictionary = {}
		for degrees in ANGLES:
			if input.get("preferredSide", 0) != 0 and degrees != 0 and sign(degrees) != input.preferredSide:
				continue
			var angle: float = degrees * PI / 180.0
			var velocity := {"x": (forward.x * cos(angle) - forward.y * sin(angle)) * speed * fraction, "y": (forward.x * sin(angle) + forward.y * cos(angle)) * speed * fraction}
			var stop_after := distance / maxf(speed * fraction, 1e-8)
			var candidate := agent.duplicate()
			candidate.velocity = velocity
			candidate.stopAfterSeconds = stop_after
			var point := Geo.at(agent.position, velocity, minf(delta, stop_after))
			if not is_allowed.call(point):
				continue
			var tick_candidate := candidate.duplicate()
			tick_candidate.stopAfterSeconds = delta
			tick_candidate.velocity = {"x": (point.x - agent.position.x) / delta, "y": (point.y - agent.position.y) / delta}
			var safe := true
			for other in neighbors:
				var tick_other: Dictionary = other.duplicate()
				tick_other.velocity = other.tickVelocity
				tick_other.stopAfterSeconds = delta
				if not _separation_is_safe(tick_candidate, tick_other, delta):
					safe = false
					break
				if not gives_way_to(agent, other) and not other.fixed and Geo.length(other.velocity) > 1e-8:
					continue
				if not _separation_is_safe(candidate, other, PREDICTION_SECONDS):
					safe = false
					break
			if not safe:
				continue
			var previous_velocity: Dictionary = input.get("previousVelocity", {"x": 0.0, "y": 0.0})
			var previous_speed := Geo.length(previous_velocity)
			var continuity: float = (velocity.x * previous_velocity.x + velocity.y * previous_velocity.y) / (speed * fraction * previous_speed) if previous_speed > 1e-8 else 1.0
			var score := distance - Geo.distance(destination, point) - 0.12 * (1.0 - continuity)
			if best.is_empty() or score > best.score + 1e-7:
				best = {"position": point, "velocity": velocity, "score": score}
		if not best.is_empty():
			return {"position": best.position, "velocity": best.velocity, "blocked": false}
	return {"position": agent.position.duplicate(), "velocity": {"x": 0.0, "y": 0.0}, "blocked": true}

static func idle_yield_target(agent: Dictionary, neighbors: Array) -> Variant:
	var ordered := neighbors.duplicate()
	ordered.sort_custom(func(a, b): return a.id < b.id)
	for other in ordered:
		if other.fixed or not gives_way_to(agent, other) or Geo.length(other.velocity) < 1e-8:
			continue
		var stationary := agent.duplicate()
		stationary.velocity = {"x": 0.0, "y": 0.0}
		stationary.stopAfterSeconds = 0.0
		if closest_approach(stationary, other, 0.6) >= 1.15:
			continue
		var speed := Geo.length(other.velocity)
		var side := {"x": -other.velocity.y / speed, "y": other.velocity.x / speed}
		var dot: float = (agent.position.x - other.position.x) * side.x + (agent.position.y - other.position.y) * side.y
		var side_sign := -1.0 if dot < 0 else 1.0
		return {"x": agent.position.x + side.x * side_sign * 1.2, "y": agent.position.y + side.y * side_sign * 1.2}
	return null
