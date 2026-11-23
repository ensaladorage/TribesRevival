extends SceneTree
## Bounded regressions for civil escape, pauses and local dodges.
const Session = preload("res://scripts/simulation/game_session.gd")
const State = preload("res://scripts/simulation/game_state.gd")
const Move = preload("res://scripts/simulation/minion_movement.gd")
const Tactics = preload("res://scripts/simulation/tactical_movement.gd")
const Geo = preload("res://scripts/simulation/geometry.gd")
const Commands = preload("res://scripts/simulation/commands.gd")
const Saves = preload("res://scripts/persistence/save_repository.gd")
var failures: Array[String] = []

func _initialize() -> void:
	check_mortality()
	check_mixed_tribe()
	check_targeted_civilians_only()
	check_enemy_focus()
	check_hit_redirects_civilian_pursuit()
	check_work_inside_combat()
	check_safe_work()
	check_phases_and_saves()
	check_phases_and_saves("hunter")
	check_hunter_flee_and_melee_focus()
	check_random_goals()
	check_interventions()
	check_blocked_escape()
	check_totem_detour()
	for failure in failures: push_error(failure)
	print("Civil flee failures: ", failures.size())
	quit(0 if failures.is_empty() else 1)

func fixture(role: String = "gatherer") -> RefCounted:
	var session := Session.new("civil-flee-regression")
	session.state.terrain = preload("res://tests/support/flat_terrain.gd").rows()
	var state: Dictionary = session.state
	state.resources = []
	state.animals = []
	state.campfires = []
	state.units = [State.create_unit("civil", role, {"x": 84.0, "y": 80.0})]
	var enemy: Dictionary = state.barbarians[0]
	enemy.position = {"x": 85.0, "y": 80.0}
	enemy.spawnPosition = enemy.position.duplicate()
	state.barbarians = [enemy]
	return session

func check_mortality() -> void:
	for role in ["gatherer", "artisan", "explorer"]:
		var session = fixture(role)
		var ticks := 0
		while not session.state.units.is_empty() and ticks < 1200:
			session.advance(0.05)
			ticks += 1
		if not session.state.units.is_empty() or session.state.phase != "defeat":
			failures.append(role + ": stationary totem permits indefinite survival")
		print("Civil mortality ", role, ": ticks=", ticks)

func check_phases_and_saves(role: String = "gatherer") -> void:
	var session = fixture(role)
	var state: Dictionary = session.state
	state.barbarians[0].health = 1000.0
	state.barbarians[0].maxHealth = 1000.0
	var unit: Dictionary = state.units[0]
	unit.health = 100.0
	unit.maxHealth = 100.0
	var seen := {}
	var saved := {}
	var maximum_dodge := 0.0
	var dodge_cycles := 0
	var dodge_distance := 0.0
	var dodge_time := 0.0
	for tick in 500:
		var previous: Dictionary = unit.position.duplicate()
		var memory: Dictionary = unit.get("fleeMemory", {}).duplicate(true)
		session.advance(0.05)
		var current: Dictionary = unit.fleeMemory
		if not Move.Nav.segment_is_clear(previous, unit.position, [Move.flee_totem_obstacle(state)], Move.TOTEM_CLEARANCE): failures.append("Flee crosses totem clearance")
		seen[current.phase] = true
		if current.phase == "dodge" and memory.get("phase") != "dodge": dodge_cycles += 1
		if memory.get("phase") == "escape" and current.phase == "escape" and memory.goal != current.goal:
			failures.append("Escape destination changes during pursuit")
		if memory.get("phase") == "pause":
			if Geo.distance(previous, unit.position) > 0.00001:
				failures.append("Civil moves voluntarily during pause")
			if memory.pauseRemaining > 0.05000001 and current.phase != "pause":
				failures.append("Pause ends early")
		if memory.get("phase") == "dodge":
			dodge_distance += Geo.distance(previous, unit.position)
			dodge_time += 0.05
			maximum_dodge = maxf(maximum_dodge, dodge_distance)
			if dodge_distance > 8.00001 or dodge_time > 1.60001:
				failures.append("Dodge exceeds distance or time budget")
		else:
			dodge_distance = 0.0
			dodge_time = 0.0
		if current.phase == "pause" and memory.get("cycle", -1) != current.cycle:
			if current.pauseRemaining < 2.0 or current.pauseRemaining > 4.0:
				failures.append("New pause outside agreed duration")
		if not saved.has(current.phase):
			saved[current.phase] = true
			check_save_continuation(state, current.phase)
	for phase in ["escape", "pause", "dodge"]:
		if not seen.has(phase): failures.append("Phase never exercised: " + phase)
	if dodge_cycles < 3 or maximum_dodge < 4.0: failures.append("Civil fails to resume substantial movement after multiple pauses")
	print("Civil phases: ", seen.keys(), " maximum dodge=", maximum_dodge)
	# Earlier v17 saves need no new required unit keys.
	var legacy: Dictionary = state.duplicate(true)
	legacy.units[0].erase("fleeMemory")
	check_save_continuation(legacy, "legacy-v17")
	var restored := Session.new("unused")
	restored.replace_state(legacy)
	restored.advance(0.05)
	if not restored.state.units[0].has("fleeMemory"): failures.append("Legacy flee state fails to initialize")

func check_random_goals() -> void:
	var session = fixture()
	var unit: Dictionary = session.state.units[0]
	unit.task.kind = "flee"
	Tactics.prepare_flee(session.state, unit)
	var goals := {}
	for cycle in 12:
		unit.fleeMemory.cycle = cycle
		var goal := Tactics._choose_flee_goal(session.state, unit, true)
		var repeated := Tactics._choose_flee_goal(session.state, unit, true)
		if goal != repeated or Geo.distance(goal, session.state.totem.position) < 4.0 or Geo.distance(goal, session.state.totem.position) > 10.0:
			failures.append("Random flee destination violates area or determinism")
		goals[JSON.stringify(goal)] = true
	if goals.size() < 6: failures.append("Flee destinations do not vary between pauses")

func check_save_continuation(state: Dictionary, phase: String) -> void:
	var saves := Saves.new("user://civil-flee-tests-only")
	var result := saves.save_slot(1, state, "test")
	var read := saves.read_slot(1)
	if not result.ok or read.status != "valid":
		failures.append("Save rejected in " + phase)
		return
	var original := Session.new("unused")
	original.replace_state(state)
	if original.state.totem.isCarried:
		Commands.apply(original.state, {"type": "drop-totem"})
	var restored := Session.new("unused")
	restored.replace_state(read.save.gameState)
	saves.delete_slot(1)
	for tick in 40:
		original.advance(0.05)
		restored.advance(0.05)
		var difference := first_difference(original.state, restored.state)
		if not difference.is_empty():
			failures.append("Save continuation diverges in " + phase + ": " + difference)
			return

func check_interventions() -> void:
	var session = fixture()
	var state: Dictionary = session.state
	var unit: Dictionary = state.units[0]
	unit.health = 100.0
	unit.maxHealth = 100.0
	for tick in 100:
		session.advance(0.05)
		if unit.fleeMemory.phase == "pause": break
	var memory: Dictionary = unit.fleeMemory
	var anchor: Dictionary = memory.anchor.duplicate()
	var cycle: int = memory.cycle
	var remaining: float = memory.pauseRemaining
	Commands.apply(state, {"type": "pick-up-totem"})
	Commands.apply(state, {"type": "drop-totem"})
	session.advance(0.05)
	if memory.cycle != cycle or memory.anchor != anchor or absf(memory.pauseRemaining - (remaining - 0.05)) > 0.00001:
		failures.append("Picking up and dropping stationary totem resets pause")
	# Switching pursuer and damage do not reset the episode either.
	var enemy: Dictionary = state.barbarians[0].duplicate(true)
	enemy.id = "replacement"
	state.barbarians = [enemy]
	Commands.apply(state, {"type": "damage-unit", "unitId": unit.id, "amount": 1.0, "sourceKind": "barbarian"})
	session.advance(0.05)
	if memory.cycle != cycle or memory.anchor != anchor: failures.append("Damage or pursuer change resets episode")
	state.phase = "paused"
	var paused: Dictionary = state.duplicate(true)
	session.advance(0.1)
	if state != paused: failures.append("Paused game advances flee memory")
	state.phase = "playing"
	Commands.apply(state, {"type": "pick-up-totem"})
	Commands.apply(state, {"type": "drag-totem", "position": {"x": 100.0, "y": 80.0}})
	remaining = memory.pauseRemaining
	var before: Dictionary = unit.position.duplicate()
	session.advance(0.05)
	if unit.state != "follow-totem" or not memory.suspended or memory.pauseRemaining != remaining or Geo.distance(unit.position, state.totem.position) >= Geo.distance(before, state.totem.position):
		failures.append("Relocated held totem fails to suspend flee and attract civil")
	for tick in 80:
		session.advance(0.05)
		if not memory.suspended: break
	if memory.suspended or memory.phase == "escape" or memory.cycle != cycle:
		failures.append("Following totem grants another escape or resets pause")
	check_save_continuation(state, "after-follow")
	state.inventory.amounts.gold = 100
	Commands.apply(state, {"type": "transform-unit", "unitId": unit.id, "item": "sword"})
	if unit.role != "guardian" or unit.has("fleeMemory"): failures.append("Transformation fails to clear flee episode")
	state.totem.position = {"x": unit.position.x - 4.0, "y": unit.position.y}
	state.barbarians[0].position = {"x": unit.position.x - 1.0, "y": unit.position.y}
	session.advance(0.05)
	if unit.task.kind != "combat": failures.append("Transformed civil fails to fight")
	# Removing the threat clears memory for civilians too.
	var calm = fixture()
	calm.advance(0.05)
	calm.state.barbarians = []
	calm.advance(0.05)
	if calm.state.units[0].has("fleeMemory"): failures.append("Ended encounter retains flee memory")

func check_blocked_escape() -> void:
	var session = fixture()
	var state: Dictionary = session.state
	var unit: Dictionary = state.units[0]
	unit.task = {"kind": "flee", "targetEntityId": state.barbarians[0].id, "targetResourceId": null, "destination": null, "cause": "threat-nearby"}
	Tactics.prepare_flee(state, unit)
	unit.fleeMemory.goal = state.barbarians[0].position.duplicate()
	unit.task.destination = unit.fleeMemory.goal.duplicate()
	for tick in 20:
		Tactics.update_flee(state, unit, 0.05, Move.create_frame(state, 0.05))
	if unit.fleeMemory.phase != "pause" or unit.fleeMemory.anchor != unit.position:
		failures.append("Blocked escape does not stop after one second")
	unit.fleeMemory.phase = "dodge"
	unit.fleeMemory.goal = state.barbarians[0].position.duplicate()
	unit.task.destination = unit.fleeMemory.goal.duplicate()
	unit.fleeMemory.dodgeRemaining = 1.6
	for tick in 32:
		Tactics.update_flee(state, unit, 0.05, Move.create_frame(state, 0.05))
	if unit.fleeMemory.phase != "pause": failures.append("Blocked dodge exceeds time budget")

func check_mixed_tribe() -> void:
	var session = fixture()
	var civil: Dictionary = session.state.units[0]
	session.state.units.append(State.create_unit("fighter", "guardian", {"x": 85.0, "y": 83.0}))
	session.advance(0.05)
	if civil.has("fleeMemory") or civil.task.kind != "avoid-combat" or session.state.units[1].task.kind != "combat":
		failures.append("Non-targeted civil should only leave nearby combat")
	check_save_continuation(session.state, "avoid-combat")
	for tick in 30:
		session.advance(0.05)
		if Tactics.combat_area_clear(session.state, civil.position): break
	if not Tactics.combat_area_clear(session.state, civil.position): failures.append("Civil fails to leave combat area")

func check_targeted_civilians_only() -> void:
	var session = fixture()
	var first: Dictionary = session.state.units[0]
	var second := State.create_unit("second", "gatherer", {"x": 76.0, "y": 80.0})
	session.state.units.append(second)
	session.advance(0.05)
	if first.task.kind != "flee" or second.task.kind == "flee" or second.has("fleeMemory"):
		failures.append("Detection forces flee on civilian that is not targeted")
	session.state.barbarians[0].position = second.position.duplicate()
	session.advance(0.05)
	if first.task.kind != "flee" or second.task.kind == "flee":
		failures.append("Enemy switches to a closer civilian while current target remains valid")
	first.position = {"x": 110.0, "y": 80.0}
	session.advance(0.05)
	if first.task.kind == "flee" or first.has("fleeMemory") or second.task.kind != "flee":
		failures.append("Flee does not follow actual enemy target changes")

func check_enemy_focus() -> void:
	var session = fixture()
	var state: Dictionary = session.state
	var prey: Dictionary = state.units[0]
	var enemy: Dictionary = state.barbarians[0]
	var guard := State.create_unit("guard", "guardian", {"x": 86.0, "y": 80.0})
	state.units.append(guard)
	enemy.targetUnitId = prey.id
	enemy.health = 1000.0
	prey.health = 1000.0
	guard.health = 1000.0
	guard.attackCooldownRemainingSeconds = 1000.0
	for tick in 100:
		session.advance(0.05)
		if enemy.targetUnitId != prey.id:
			failures.append("Enemy abandons living prey for a nearby attacker")
			break
	check_save_continuation(state, "enemy-focus")
	state.inventory.amounts.gold = 100
	Commands.apply(state, {"type": "transform-unit", "unitId": prey.id, "item": "sword"})
	session.advance(0.05)
	if prey.role != "guardian" or enemy.targetUnitId != prey.id:
		failures.append("Transformation resets enemy focus")
	# An attacker substantially closer than the current combatant cannot steal focus.
	prey.position = {"x": enemy.position.x + 7.0, "y": enemy.position.y}
	guard.position = {"x": enemy.position.x + 1.0, "y": enemy.position.y}
	if Session.Conflict._barbarian_target(state, enemy) != prey:
		failures.append("Distance advantage steals focus from current combatant")
	Session.Conflict._attack(state, guard, enemy, Move.Combat.minion_attack(guard.role, 0), "barbarian")
	if enemy.targetUnitId != prey.id: failures.append("Hit steals focus from a combat-capable target")
	# A defeated target still present in a snapshot is invalid; removed targets too.
	prey.health = 0.0
	if Session.Conflict._barbarian_target(state, enemy) != guard:
		failures.append("Enemy keeps defeated target")
	state.units.erase(prey)
	if Session.Conflict._barbarian_target(state, enemy) != guard:
		failures.append("Enemy fails to reacquire after target removal")
	# Existing death/respawn logic must clear the retained ID.
	Session.Conflict._defeat_barbarian(state, enemy)
	if enemy.targetUnitId != null: failures.append("Defeated enemy retains focus")

func check_hit_redirects_civilian_pursuit() -> void:
	for role in ["guardian", "lumberjack", "hunter"]:
		var session = fixture()
		var state: Dictionary = session.state
		var enemy: Dictionary = state.barbarians[0]
		var civil: Dictionary = state.units[0]
		var fighter := State.create_unit("fighter", role, {"x": 86.0, "y": 80.0})
		state.units.append(fighter)
		enemy.health = 100.0
		enemy.targetUnitId = civil.id
		Session.Conflict._attack(state, fighter, enemy, {"damage": 0.0, "cooldownSeconds": 1.0}, "barbarian")
		if role == "hunter":
			var harmless: Dictionary = state.hunterShots[0]
			state.tick = harmless.releaseTick
			Session.Conflict.update_hunter_shots(state)
			state.tick = harmless.impactTick
			Session.Conflict.update_hunter_shots(state)
		if enemy.targetUnitId != civil.id: failures.append("Zero damage redirects pursuit")
		Session.Conflict._attack(state, fighter, enemy, Move.Combat.minion_attack(role, 0), "barbarian")
		if role == "hunter":
			var rescue: Dictionary = state.hunterShots.back()
			state.tick = rescue.releaseTick
			Session.Conflict.update_hunter_shots(state)
			if enemy.targetUnitId != civil.id: failures.append("Arrow in flight redirects pursuit before impact")
			state.tick = rescue.impactTick
			Session.Conflict.update_hunter_shots(state)
		if enemy.targetUnitId != fighter.id: failures.append(role + ": landed hit fails to rescue civil")
		var second := State.create_unit("second-fighter", "guardian", {"x": 85.0, "y": 81.0})
		state.units.append(second)
		Session.Conflict._attack(state, second, enemy, Move.Combat.minion_attack("guardian", 0), "barbarian")
		if enemy.targetUnitId != (second.id if role == "hunter" else fighter.id): failures.append("Melee rescue violates focus priority")
		check_save_continuation(state, "redirected-focus-" + role)
		session.advance(0.05)
		if civil.task.kind == "flee" or civil.has("fleeMemory"): failures.append("Rescued civil continues fleeing")
		enemy.targetUnitId = civil.id
		enemy.health = 1.0
		Session.Conflict._attack(state, second, enemy, Move.Combat.minion_attack("guardian", 0), "barbarian")
		if enemy.isAlive or enemy.targetUnitId != null: failures.append("Lethal rescue hit retains enemy focus")

func check_hunter_flee_and_melee_focus() -> void:
	var session = fixture("hunter")
	var state: Dictionary = session.state
	var hunter: Dictionary = state.units[0]
	var enemy: Dictionary = state.barbarians[0]
	enemy.health = 1000.0
	enemy.maxHealth = 1000.0
	var shots := 0
	for tick in 1200:
		var health: float = enemy.health
		session.advance(0.05)
		if enemy.health < health:
			shots += 1
			if hunter.task.kind != "flee" or hunter.fleeMemory.phase != "pause" or Geo.distance(hunter.position, enemy.position) > 5.00001:
				failures.append("Pursued hunter fires outside a stationary flee pause or range")
		if state.units.is_empty(): break
	if shots == 0: failures.append("Pursued hunter loses ranged attack")
	if not state.units.is_empty(): failures.append("Hunter can kite indefinitely around a stationary totem")
	for role in ["guardian", "lumberjack"]:
		session = fixture("hunter")
		state = session.state
		hunter = state.units[0]
		enemy = state.barbarians[0]
		var fighter := State.create_unit("melee", role, {"x": 89.0, "y": 80.0})
		state.units.append(fighter)
		Session.Work.set_task(hunter, Session.Conflict._entity_task("combat", "test", enemy.id))
		Session.Work.set_task(fighter, Session.Conflict._entity_task("combat", "test", enemy.id))
		if Session.Conflict._barbarian_target(state, enemy) != fighter:
			failures.append(role + ": acquisition prefers nearer hunter over melee attacker")
		enemy.targetUnitId = hunter.id
		if Session.Conflict._barbarian_target(state, enemy) != fighter:
			failures.append(role + ": enemy keeps chasing hunter despite engaged melee")
		enemy.targetUnitId = fighter.id
		if Session.Conflict._barbarian_target(state, enemy) != fighter:
			failures.append(role + ": melee focus is unstable")
		fighter.position = {"x": 110.0, "y": 80.0}
		if Session.Conflict._barbarian_target(state, enemy) != hunter:
			failures.append(role + ": enemy prefers melee outside detection range")
		state.units.erase(fighter)
		hunter.health = 100.0
		enemy.health = 100.0
		enemy.targetUnitId = hunter.id
		session.advance(0.05)
		fighter.position = {"x": 89.0, "y": 80.0}
		state.units.append(fighter)
		session.advance(0.05)
		if enemy.targetUnitId != fighter.id or hunter.task.kind == "flee" or hunter.has("fleeMemory"):
			failures.append(role + ": rescued hunter retains flee episode")
		session.advance(0.05)
		if hunter.task.kind != "combat": failures.append("Rescued hunter fails to resume ranged combat")

func check_work_inside_combat() -> void:
	var session = fixture()
	var state: Dictionary = session.state
	var civil: Dictionary = state.units[0]
	var enemy: Dictionary = state.barbarians[0]
	var guard := State.create_unit("guard", "guardian", {"x": 86.0, "y": 80.0})
	state.units.append(guard)
	enemy.targetUnitId = guard.id
	enemy.health = 1000.0
	var loot := State.empty_amounts()
	loot.wood = 1
	state.barbarianCorpses = [{"id": "test-corpse", "position": civil.position.duplicate(), "loot": loot}]
	civil.position = {"x": 79.0, "y": 76.0}
	for tick in 100:
		session.advance(0.05)
		if civil.task.kind in ["flee", "avoid-combat"]: failures.append("Corpse looting oscillates near untargeting enemy")
		if state.barbarianCorpses.is_empty(): break
	if not state.barbarianCorpses.is_empty() or state.drops.is_empty(): failures.append("Civil cannot finish looting inside combat area")
	if not state.drops.is_empty():
		state.drops[0].position = civil.position.duplicate()
		session.advance(0.05)
		if not state.drops.is_empty(): failures.append("Civil refuses a floor drop inside combat area")
	# Start from an idle civil inside the fight: allow choosing a nearby node.
	state.drops = []
	var node: Dictionary = State.create_initial().resources.filter(func(resource): return resource.source == "berry-bush")[0].duplicate(true)
	node.position = {"x": 83.0, "y": 80.0}
	state.resources = [node]
	Session.Work.set_task(civil, {"kind": "idle", "targetResourceId": null, "destination": null, "cause": "test"})
	session.advance(0.05)
	if civil.task.kind != "gather": failures.append("Civil refuses node near untargeting enemy")
	check_save_continuation(state, "work-near-combat")
	# Real targeting still interrupts work even beside a corpse/resource.
	state.units.erase(guard)
	enemy.targetUnitId = civil.id
	session.advance(0.05)
	if civil.task.kind != "flee": failures.append("Working civil ignores actual pursuit")

func check_safe_work() -> void:
	var session = fixture()
	var state: Dictionary = session.state
	var civil: Dictionary = state.units[0]
	civil.position = {"x": 75.0, "y": 80.0}
	state.units.append(State.create_unit("guard", "guardian", {"x": 86.0, "y": 80.0}))
	var node: Dictionary = State.create_initial().resources.filter(func(resource): return resource.source == "berry-bush")[0].duplicate(true)
	node.position = civil.position.duplicate()
	node.position.x -= node.interactionRadius
	state.resources = [node]
	civil.task = {"kind": "gather", "targetResourceId": node.id, "destination": node.position.duplicate(), "cause": "resource-found"}
	civil.actionProgressSeconds = 1.0
	civil.state = "gathering"
	session.advance(0.05)
	if civil.task.kind != "gather" or civil.actionProgressSeconds <= 1.0 or civil.has("fleeMemory"):
		failures.append("Safe gathering is interrupted by enemy targeting guard")
	state.resources = []
	Session.Work.drop_resource(state, civil.position, "test", "test", "wood", 1)
	var drop: Dictionary = state.drops[0]
	drop.position = civil.position.duplicate()
	Session.Work.set_task(civil, {"kind": "collect-drop", "targetResourceId": drop.id, "destination": drop.position.duplicate(), "cause": "drop-found"})
	session.advance(0.05)
	if not state.drops.is_empty() or civil.has("fleeMemory"):
		failures.append("Safe floor drop collection is interrupted")
	for tick in 10: session.advance(0.05)
	if civil.task.kind != "idle" or civil.has("fleeMemory"):
		failures.append("Safe civilian cannot idle while guard fights")

func check_totem_detour() -> void:
	var cases: Array = []
	for index in 4: cases.append({"center": {"x": 80.0, "y": 80.0}, "direction": Vector2.from_angle(index * PI / 2.0)})
	for x in [2.0, 158.0]:
		for sign_y in [-1.0, 1.0]: cases.append({"center": {"x": x, "y": 80.0}, "direction": Vector2(0.0, sign_y)})
	for y in [2.0, 158.0]:
		for sign_x in [-1.0, 1.0]: cases.append({"center": {"x": 80.0, "y": y}, "direction": Vector2(sign_x, 0.0)})
	for config in cases:
		var session = fixture()
		var state: Dictionary = session.state
		var enemy: Dictionary = state.barbarians[0]
		var unit: Dictionary = state.units[0]
		state.totem.position = config.center.duplicate()
		var direction: Vector2 = config.direction
		enemy.position = {"x": config.center.x + direction.x * 5.0, "y": config.center.y + direction.y * 5.0}
		unit.position = {"x": config.center.x - direction.x * 9.0, "y": config.center.y - direction.y * 9.0}
		unit.health = 100.0
		for tick in 160:
			var before: Dictionary = enemy.position.duplicate()
			Session.Conflict._update_barbarian(state, enemy, 0.05, Move.create_frame(state, 0.05))
			if Geo.distance(enemy.position, state.totem.position) < Move.TOTEM_CLEARANCE - 0.00001 or Geo.distance(enemy.position, before) > 0.35001:
				failures.append("Enemy detour violates clearance or chase speed")
		if unit.health >= 100.0: failures.append("Totem blocks enemy pursuing stationary civilian")

func first_difference(a: Variant, b: Variant, path: String = "state") -> String:
	if (a is float or a is int) and (b is float or b is int):
		return "" if absf(float(a) - float(b)) < 0.000001 else path + ": %s != %s" % [a, b]
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return path + ": dictionary size"
		for key in a:
			if not b.has(key): return path + ": missing " + str(key)
			var difference := first_difference(a[key], b[key], path + "." + str(key))
			if not difference.is_empty(): return difference
		return ""
	if a is Array and b is Array:
		if a.size() != b.size(): return path + ": array size"
		for index in a.size():
			var difference := first_difference(a[index], b[index], path + "[%s]" % index)
			if not difference.is_empty(): return difference
		return ""
	return "" if a == b else path + ": %s != %s" % [a, b]
