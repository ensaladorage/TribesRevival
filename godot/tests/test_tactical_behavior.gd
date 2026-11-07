extends SceneTree
const Session = preload("res://scripts/simulation/game_session.gd")
const State = preload("res://scripts/simulation/game_state.gd")
const Geo = preload("res://scripts/simulation/geometry.gd")
const Tactics = preload("res://scripts/simulation/tactical_movement.gd")
const Conflict = preload("res://scripts/simulation/conflict_system.gd")
const Movement = preload("res://scripts/simulation/minion_movement.gd")
var failures: Array[String] = []
func _initialize() -> void:
	check_decisions()
	check_normal_combat()
	var first := scenario(false)
	var repeat := scenario(false)
	var fight := scenario(true)
	print("Civilian pursuit: ", first)
	print("Outnumbered barbarian: ", fight)
	if first != repeat: failures.append("Non deterministic pursuit")
	if first.maximum_radius > 10.00001: failures.append("Civilian leaves command radius")
	if first.reversals > first.moving_steps / 5: failures.append("Civilian repeatedly reverses direction")
	if first.travel < 20: failures.append("Pursued civilian stops moving")
	if fight.enemy_travel < 2: failures.append("Outnumbered barbarian remains stationary")
	if fight.damage_dealt <= 0: failures.append("Barbarian never retaliates")
	if not failures.is_empty():
		for failure in failures: push_error(failure)
		quit(1)
	else:
		print("PASS tactical scenarios")
		quit()
func scenario(combat: bool) -> Dictionary:
	var session = Session.new("tactical-test")
	var state: Dictionary = session.state
	state.animals = []
	state.resources = []
	state.units = []
	var enemy: Dictionary = state.barbarians[0].duplicate(true)
	enemy.position = {"x": 85.0, "y": 80.0}
	enemy.spawnPosition = enemy.position.duplicate()
	enemy.health = 100.0
	enemy.maxHealth = 100.0
	state.barbarians = [enemy]
	for i in (3 if combat else 1):
		var unit = State.create_unit("test-%s" % i, "guardian" if combat else "gatherer", {"x": 83.5, "y": 80.0 + i * 1.5})
		unit.health = 100.0
		unit.maxHealth = 100.0
		state.units.append(unit)
	var travel := 0.0
	var enemy_travel := 0.0
	var maximum_radius := 0.0
	var previous_direction := Vector2.ZERO
	var reversals := 0
	var moving_steps := 0
	for tick in 240:
		var previous: Dictionary = state.units[0].position.duplicate()
		var previous_enemy: Dictionary = enemy.position.duplicate()
		session.advance(0.05)
		travel += Geo.distance(previous, state.units[0].position)
		var direction := Vector2(state.units[0].position.x - previous.x, state.units[0].position.y - previous.y)
		if direction.length() > 0.01:
			moving_steps += 1
			if previous_direction.length_squared() > 0 and direction.normalized().dot(previous_direction) < -0.5:
				reversals += 1
			previous_direction = direction.normalized()
		enemy_travel += Geo.distance(previous_enemy, enemy.position)
		maximum_radius = maxf(maximum_radius, Geo.distance(state.units[0].position, state.totem.position))
	var health := 0.0
	for unit in state.units: health += unit.health
	return {"travel": travel, "enemy_travel": enemy_travel, "maximum_radius": maximum_radius, "damage_dealt": state.units.size() * 100.0 - health, "reversals": reversals, "moving_steps": moving_steps, "final": state.units[0].position.duplicate()}

func check_decisions() -> void:
	var session = Session.new("decisions")
	var state: Dictionary = session.state
	state.resources = []
	state.animals = []
	var enemy: Dictionary = state.barbarians[0].duplicate(true)
	enemy.position = {"x": 85.0, "y": 80.0}
	enemy.spawnPosition = enemy.position.duplicate()
	state.barbarians = [enemy]
	var civil = State.create_unit("civil", "gatherer", {"x": 84.0, "y": 80.0})
	var fighter = State.create_unit("fighter", "guardian", {"x": 86.5, "y": 80.0})
	fighter.task = {"kind": "combat", "targetEntityId": enemy.id, "targetResourceId": null, "destination": null, "cause": "threat-nearby"}
	state.units = [civil, fighter]
	Conflict._update_barbarian(state, enemy, 0.05, Movement.create_frame(state, 0.05))
	if enemy.targetUnitId != fighter.id: failures.append("Barbarian ignores fighter for closer civilian")
	state.units = [civil]
	civil.position = {"x": 75.0, "y": 80.0}
	if Geo.distance(civil.position, Tactics.flee_goal(state, civil)) > 0.001: failures.append("Safe civilian keeps fleeing unnecessarily")
	state.phase = "paused"
	var before = state.duplicate(true)
	session.advance(0.1)
	if state != before: failures.append("Paused simulation advances tactics")
	state.phase = "playing"
	civil.task = {"kind": "flee", "targetEntityId": enemy.id, "targetResourceId": null, "destination": null, "cause": "threat-nearby"}
	enemy.isAlive = false
	enemy.respawnRemainingSeconds = 60.0
	session.advance(0.05)
	if civil.task.kind == "flee": failures.append("Civilian does not stop fleeing after threat dies")
	enemy.isAlive = true
	enemy.position = {"x": 120.0, "y": 80.0}
	enemy.targetUnitId = civil.id
	enemy.returningToSpawn = false
	var old_distance = Geo.distance(enemy.position, enemy.spawnPosition)
	Conflict._update_barbarian(state, enemy, 0.05, Movement.create_frame(state, 0.05))
	if not enemy.returningToSpawn or Geo.distance(enemy.position, enemy.spawnPosition) >= old_distance: failures.append("Enemy does not return when encounter ends")

	# A distant totem relocation must not teleport a fleeing civilian.
	civil.position = {"x": 98.0, "y": 80.0}
	enemy.position = {"x": 100.0, "y": 80.0}
	var outside_start: Dictionary = civil.position.duplicate()
	session.advance(0.05)
	if Geo.distance(outside_start, civil.position) > 0.50001 or Geo.distance(civil.position, state.totem.position) >= 18.0:
		failures.append("Civilian outside relocated command area teleports or fails to return")

func check_normal_combat() -> void:
	var session := Session.new("normal-combat")
	var state: Dictionary = session.state
	state.animals = []
	state.resources = []
	var enemy: Dictionary = state.barbarians[0].duplicate(true)
	enemy.position = {"x": 85.0, "y": 80.0}
	enemy.spawnPosition = enemy.position.duplicate()
	state.barbarians = [enemy]
	state.units = []
	for i in 3:
		state.units.append(State.create_unit("normal-%s" % i, "guardian" if i < 2 else "gatherer", {"x": 83.5, "y": 78.5 + i * 1.5}))
	var saw_corpse := false
	var saw_loot := false
	for tick in 600:
		session.advance(0.05)
		saw_corpse = saw_corpse or not state.barbarianCorpses.is_empty()
		saw_loot = saw_loot or not state.drops.is_empty()
	if enemy.isAlive or not saw_corpse or not saw_loot: failures.append("Normal combat fails to defeat enemy and produce loot")
	if not state.barbarianCorpses.is_empty(): failures.append("Normal corpse cannot be looted")
	print("Normal combat: defeated=", not enemy.isAlive, " corpse=", saw_corpse, " loot=", saw_loot)
