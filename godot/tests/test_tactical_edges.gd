extends SceneTree
const Session = preload("res://scripts/simulation/game_session.gd")
const State = preload("res://scripts/simulation/game_state.gd")
const Geo = preload("res://scripts/simulation/geometry.gd")
const Saves = preload("res://scripts/persistence/save_repository.gd")
var failures: Array[String] = []
func _initialize() -> void:
	if "--crowded-only" in OS.get_cmdline_user_args():
		run_case({"name": "eight-two-enemies", "corner": false, "moving": false, "count": 8, "enemies": 2})
		for failure in failures: push_error(failure)
		quit(1 if not failures.is_empty() else 0)
		return
	for config in [{"name": "group", "corner": false, "moving": false}, {"name": "corner", "corner": true, "moving": false}, {"name": "moving", "corner": false, "moving": true}]:
		run_case(config)
	for sx in [-1, 1]:
		for sy in [-1, 1]:
			if sx == 1 and sy == 1: continue
			run_case({"name": "corner-%s-%s" % [sx, sy], "corner": true, "moving": false, "sx": sx, "sy": sy})
	run_case({"name": "eight-two-enemies", "corner": false, "moving": false, "count": 8, "enemies": 2})
	for failure in failures: push_error(failure)
	print("Tactical edge failures: ", failures.size())
	quit(1 if not failures.is_empty() else 0)
func run_case(config: Dictionary) -> void:
	var session = Session.new("tactical-edges")
	var state: Dictionary = session.state
	state.resources = []
	state.animals = []
	state.units = []
	var sx: int = config.get("sx", 1)
	var sy: int = config.get("sy", 1)
	var center := {"x": (5.0 if sx == 1 else 155.0) if config.corner else 80.0, "y": (5.0 if sy == 1 else 155.0) if config.corner else 80.0}
	state.totem.position = center.duplicate()
	state.totem.isCarried = config.moving
	for i in int(config.get("count", 6)):
		var point := {"x": center.x + sx * (3.0 + (i % 3) * 1.3), "y": center.y + sy * (1.0 + floori(i / 3.0) * 1.3)}
		var unit = State.create_unit("civil-%s" % i, "gatherer" if i % 2 == 0 else "artisan", point)
		unit.health = 100.0
		unit.maxHealth = 100.0
		state.units.append(unit)
	var enemy: Dictionary = state.barbarians[0].duplicate(true)
	enemy.position = {"x": center.x + sx * 7, "y": center.y + sy * 1}
	enemy.spawnPosition = enemy.position.duplicate()
	state.barbarians = [enemy]
	if config.get("enemies", 1) == 2:
		var second: Dictionary = enemy.duplicate(true)
		second.id = "second-enemy"
		second.position = {"x": center.x - 4.0, "y": center.y + 3.0}
		second.spawnPosition = second.position.duplicate()
		state.barbarians.append(second)
	var max_radius := 0.0
	var max_step := 0.0
	var minimum_spacing := INF
	var longest_stop := 0
	var longest_outside := 0
	var outside_ticks := {}
	var stopped := {}
	var paths := {}
	for unit in state.units:
		stopped[unit.id] = 0
		outside_ticks[unit.id] = 0
		paths[unit.id] = 0.0
	var resumed = null
	for tick in 400:
		if config.moving and tick < 300: state.totem.position.x += 0.04
		var before := {}
		for unit in state.units: before[unit.id] = unit.position.duplicate()
		session.advance(0.05)
		if tick == 200:
			var directory := "user://tactical-regression-only"
			var saves = Saves.new(directory)
			var result = saves.save_slot(1, state, "test")
			var read = saves.read_slot(1)
			if not result.ok or read.status != "valid": failures.append(config.name + ": save rejected")
			else:
				resumed = Session.new("unused")
				resumed.replace_state(read.save.gameState)
			saves.delete_slot(1)
		elif tick > 200 and resumed != null:
			if config.moving and tick < 300: resumed.state.totem.position.x += 0.04
			resumed.advance(0.05)
			if tick == 399:
				for i in state.units.size():
					if Geo.distance(state.units[i].position, resumed.state.units[i].position) > 0.00001: failures.append(config.name + ": save continuation diverges")
		for unit in state.units:
			var step := Geo.distance(before[unit.id], unit.position)
			var radius_now := Geo.distance(unit.position, state.totem.position)
			var allowed_radius := maxf(state.totem.commandRadius, Geo.distance(before[unit.id], state.totem.position))
			if radius_now > allowed_radius + 0.00001: failures.append(config.name + ": civilian voluntarily exits command area")
			outside_ticks[unit.id] = outside_ticks[unit.id] + 1 if radius_now > 10.00001 else 0
			longest_outside = maxi(longest_outside, outside_ticks[unit.id])
			if tick == 399 and radius_now > 10.00001: failures.append(config.name + ": fails to return after totem stops")
			max_step = maxf(max_step, step)
			paths[unit.id] += step
			max_radius = maxf(max_radius, Geo.distance(unit.position, state.totem.position))
			if unit.position.x < 2 or unit.position.y < 2 or unit.position.x > 158 or unit.position.y > 158: failures.append(config.name + ": outside map")
			stopped[unit.id] = stopped[unit.id] + 1 if step < 0.01 and Geo.distance(unit.position, enemy.position) < 5.0 else 0
			longest_stop = maxi(longest_stop, stopped[unit.id])
			if tick > 10:
				for other in state.units:
					if other.id != unit.id: minimum_spacing = minf(minimum_spacing, Geo.distance(unit.position, other.position))
	print(config.name, ": radius=", max_radius, " max_step=", max_step, " spacing=", minimum_spacing, " stopped_near_threat=", longest_stop * 0.05, " paths=", paths)
	if max_radius > (10.04001 if config.moving else 10.00001): failures.append(config.name + ": command radius exceeded")
	if longest_outside > 20: failures.append(config.name + ": outside command for over a second")
	if max_step > 0.75: failures.append(config.name + ": abrupt movement")
	if longest_stop > 60: failures.append(config.name + ": stuck near enemy for over 3 seconds")
	if minimum_spacing < 0.85: failures.append(config.name + ": civilians overlap")
