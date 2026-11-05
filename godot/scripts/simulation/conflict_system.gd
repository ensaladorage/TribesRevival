class_name TribeConflictSystem
extends RefCounted
## Combat, fauna, respawn and loot. Rendering never decides hits or targets.

const Combat = preload("res://scripts/simulation/combat_rules.gd")
const Move = preload("res://scripts/simulation/minion_movement.gd")
const Work = preload("res://scripts/simulation/work_system.gd")
const Rules = preload("res://scripts/simulation/survival_rules.gd")
const Survival = preload("res://scripts/simulation/survival_system.gd")
const Geo = preload("res://scripts/simulation/geometry.gd")
const Nav = preload("res://scripts/simulation/navigation.gd")
const Slots = preload("res://scripts/simulation/combat_positions.gd")
const Awareness = preload("res://scripts/simulation/minion_awareness.gd")
const State = preload("res://scripts/simulation/game_state.gd")
const Random = preload("res://scripts/simulation/seeded_random.gd")
const Progression = preload("res://scripts/simulation/progression.gd")
const Weather = preload("res://scripts/simulation/weather_system.gd")

static func _entity_task(kind: String, cause: String, target_id: String) -> Dictionary:
	return {"kind": kind, "cause": cause, "targetResourceId": null, "targetEntityId": target_id, "destination": null}

static func _patrol_wait(state: Dictionary, actor: Dictionary, cycle: int) -> float:
	return Random.new("%s:%s:patrol-wait:%s:%s" % [state.seed, actor.id, cycle, actor.patrolStep]).next_float(2, 4)

static func _patrol_point(seed_text: String, id: String, cycle: int, step: int, center: Dictionary, radius: float) -> Dictionary:
	var random := Random.new("%s:%s:patrol:%s:%s" % [seed_text, id, cycle, step])
	var angle := random.next_float(0, PI * 2.0)
	var distance := sqrt(random.next_float(0, radius * radius))
	return State.clamp_position({"x": center.x + cos(angle) * distance, "y": center.y + sin(angle) * distance})

static func _nearest(point: Dictionary, entities: Array, radius: float, living_only: bool = true) -> Variant:
	var candidates: Array = entities.filter(func(entity): return (not living_only or entity.isAlive) and Geo.distance(point, entity.position) <= radius)
	candidates.sort_custom(func(a, b):
		var difference := Geo.distance(point, a.position) - Geo.distance(point, b.position)
		return difference < 0 if difference != 0 else a.id < b.id)
	return candidates[0] if not candidates.is_empty() else null

static func _living(entities: Array, id: Variant) -> Variant:
	var entity: Variant = Move.find_entity(entities, id)
	return entity if entity != null and entity.isAlive else null

static func _defeat_barbarian(state: Dictionary, barbarian: Dictionary) -> void:
	if not barbarian.isAlive:
		return
	Progression.award_experience(state.progression, 5)
	barbarian.health = 0.0
	barbarian.isAlive = false
	barbarian.respawnRemainingSeconds = 60.0
	barbarian.targetUnitId = null
	state.alerts = state.alerts.filter(func(alert): return alert.detectorKind != "barbarian" or alert.detectorId != barbarian.id)
	var random := Random.new("%s:barbarian-loot:%s:%s" % [state.seed, barbarian.id, barbarian.spawnCycle])
	var loot := State.empty_amounts()
	loot.gold = random.next_int(1, 2)
	loot.food = random.next_int(0, 2)
	loot.wood = random.next_int(0, 1)
	state.barbarianCorpses.append({"id": "corpse-%s-%s" % [barbarian.id, barbarian.spawnCycle], "barbarianId": barbarian.id, "position": barbarian.position.duplicate(), "loot": loot})

static func _attack(state: Dictionary, unit: Dictionary, target: Dictionary, stats: Dictionary, kind: String) -> bool:
	unit.attackCooldownRemainingSeconds = stats.cooldownSeconds
	unit.attackLockRemainingSeconds = 0.22
	Survival.add_effect(state, "attack-lunge", unit.id, target.position, 0.22)
	var result := Combat.deal_damage("minion", kind, target, stats.damage)
	target.health = result.health
	if kind == "barbarian" and result.damageApplied > 0:
		Survival.add_effect(state, "damage-flash", target.id, target.position, 0.3)
	if result.defeated:
		if kind == "barbarian":
			_defeat_barbarian(state, target)
		elif target.isAlive:
			Progression.award_experience(state.progression, 3)
			target.health = 0.0
			target.isAlive = false
			target.respawnRemainingSeconds = 30.0
			var random := Random.new("%s:rabbit-loot:%s:%s" % [state.seed, target.id, target.spawnCycle])
			Work.drop_resource(state, target.position, target.id, target.id, "food", random.next_int(1, 2))
	return result.defeated

static func _update_respawns_and_fauna(state: Dictionary, delta: float) -> void:
	for barbarian in state.barbarians:
		if barbarian.isAlive:
			continue
		barbarian.respawnRemainingSeconds = maxf(barbarian.respawnRemainingSeconds - delta, 0)
		if barbarian.respawnRemainingSeconds < 1e-9:
			barbarian.respawnRemainingSeconds = 0.0
		if barbarian.respawnRemainingSeconds > 0:
			continue
		barbarian.isAlive = true
		barbarian.health = barbarian.maxHealth
		barbarian.position = barbarian.spawnPosition.duplicate()
		barbarian.patrolTarget = barbarian.spawnPosition.duplicate()
		barbarian.patrolStep = 0
		barbarian.returningToSpawn = false
		barbarian.patrolWaitRemainingSeconds = _patrol_wait(state, barbarian, barbarian.spawnCycle + 1)
		barbarian.attackProgressSeconds = 2.5
		barbarian.targetUnitId = null
		barbarian.alertedUnitIds = []
		barbarian.alertSoundedThisEncounter = false
		barbarian.spawnCycle += 1
	for animal in state.animals:
		if not animal.isAlive:
			animal.respawnRemainingSeconds = maxf(animal.respawnRemainingSeconds - delta, 0)
			if animal.respawnRemainingSeconds < 1e-9:
				animal.respawnRemainingSeconds = 0.0
			if animal.respawnRemainingSeconds > 0:
				continue
			animal.isAlive = true
			animal.health = animal.maxHealth
			animal.position = animal.spawnPosition.duplicate()
			animal.patrolTarget = _patrol_point(state.seed, animal.id, animal.spawnCycle + 1, animal.spawnCycle + 1, animal.homeCenter, animal.homeRadius)
			animal.spawnCycle += 1
			continue
		if Geo.distance(animal.position, animal.patrolTarget) <= 0.2:
			animal.patrolTarget = _patrol_point(state.seed, animal.id, animal.spawnCycle, state.tick, animal.homeCenter, animal.homeRadius)
		Weather.move_point(animal.position, animal.patrolTarget, 1.2 * delta)

static func _choose_combat_target(state: Dictionary, unit: Dictionary) -> Variant:
	var current: Variant = _living(state.barbarians, unit.task.get("targetEntityId"))
	if current != null and Geo.distance(unit.position, current.position) <= 18.0:
		return current
	var candidates: Array = state.barbarians.filter(func(barbarian): return barbarian.isAlive and Geo.distance(unit.position, barbarian.position) <= 18.0)
	var engagers := func(id: String) -> int:
		var count := 0
		for candidate in state.units:
			if candidate.id != unit.id and candidate.task.kind == "combat" and candidate.task.get("targetEntityId") == id:
				count += 1
		return count
	candidates.sort_custom(func(a, b):
		var difference: float = engagers.call(a.id) - engagers.call(b.id)
		if difference == 0:
			difference = Geo.distance(unit.position, a.position) - Geo.distance(unit.position, b.position)
		return difference < 0 if difference != 0 else a.id < b.id)
	return candidates[0] if not candidates.is_empty() else null

static func _reserve_combat(state: Dictionary, frame: Dictionary) -> void:
	var targets: Array = state.barbarians.filter(func(other): return other.isAlive)
	targets.sort_custom(func(a, b): return a.id < b.id)
	for target in targets:
		var attackers: Array = state.units.filter(func(unit): return unit.task.kind == "combat" and unit.task.get("targetEntityId") == target.id)
		var occupied: Array = state.units.filter(func(unit): return unit not in attackers and Move.holds_working_position(state, unit)).map(func(unit): return unit.position)
		occupied.append_array(frame.combatPositions.values())
		var descriptors: Array = []
		for unit in attackers:
			var memory: Dictionary = unit.get("navigation", {})
			descriptors.append({"id": unit.id, "position": unit.position, "range": Combat.minion_attack(unit.role, state.toolLevels.sword).range, "ranged": unit.role == "hunter", "offset": memory.get("combatOffset") if memory.get("combatTargetId") == target.id else null})
		var allowed := func(attacker: Dictionary, point: Dictionary) -> bool:
			if point.x < 2 or point.y < 2 or point.x > 158 or point.y > 158 or Geo.distance(point, state.totem.position) < 2.02:
				return false
			if attacker.ranged and Geo.distance(point, state.totem.position) > minf(state.totem.commandRadius, 10.0):
				return false
			for other in state.barbarians:
				if other.isAlive and other.id != target.id and Geo.distance(point, other.position) < 0.94:
					return false
			return true
		var positions := Slots.assign(target.position, descriptors, occupied, allowed)
		for unit in attackers:
			var point: Dictionary = positions[unit.id]
			frame.combatPositions[unit.id] = point
			if not unit.has("navigation"):
				unit.navigation = Nav.create_state(point)
			unit.navigation.combatTargetId = target.id
			unit.navigation.combatOffset = {"x": point.x - target.position.x, "y": point.y - target.position.y}

static func _move_barbarian(state: Dictionary, barbarian: Dictionary, destination: Dictionary, distance: float, frame: Dictionary) -> bool:
	var zero := {"x": 0.0, "y": 0.0}
	var neighbors: Array = []
	for unit in state.units:
		var origin: Dictionary = frame.origins.get(unit.id, unit.position)
		var velocity: Dictionary = frame.reservations.get(unit.id, {}).get("tickVelocity", zero)
		neighbors.append({"id": unit.id, "position": origin, "velocity": velocity, "tickVelocity": velocity, "stopAfterSeconds": frame.deltaSeconds, "fixed": true, "priority": 4})
	for other in state.barbarians:
		if other.isAlive and other.id != barbarian.id:
			neighbors.append({"id": other.id, "position": other.position, "velocity": zero, "tickVelocity": zero, "stopAfterSeconds": 0.0, "fixed": true, "priority": 4})
	var input := {"agent": {"id": barbarian.id, "position": barbarian.position, "velocity": zero, "tickVelocity": zero, "stopAfterSeconds": 0.0, "fixed": false, "priority": 2}, "destination": destination, "speed": distance / frame.deltaSeconds, "deltaSeconds": frame.deltaSeconds, "neighbors": neighbors}
	var result := Nav.choose_step(input, func(point): return point.x >= 2 and point.y >= 2 and point.x <= 158 and point.y <= 158)
	barbarian.position.merge(result.position, true)
	return Geo.distance(barbarian.position, destination) <= 0.08

static func update(state: Dictionary, delta: float, frame: Dictionary) -> void:
	_update_respawns_and_fauna(state, delta)
	var moving: bool = state.totem.isCarried or state.totem.moving
	var units: Array = []
	for unit in state.units:
		units.append({"id": unit.id, "position": unit.position, "currentKind": unit.task.kind, "currentTargetId": unit.task.get("targetEntityId"), "available": unit.task.kind in ["idle", "return-to-totem"] and Rules.total_amount(unit.cargo.amounts) == 0, "canFight": Combat.minion_attack(unit.role, state.toolLevels.sword) != null, "canHunt": unit.role == "hunter"})
	var entities: Array = []
	for entity in state.barbarians + state.animals:
		entities.append({"id": entity.id, "position": entity.position, "isAlive": entity.isAlive, "kind": "hunt" if entity.has("kind") else "combat"})
	var calls: Dictionary = {} if moving else Awareness.choose_calls(units, entities, 18, maxf(state.totem.commandRadius, 0) * 1.05, func(unit, entity): return entity.kind != "combat" or not unit.canHunt or Geo.distance(entity.position, state.totem.position) <= minf(state.totem.commandRadius, 10.0) + Slots.position_radius(Combat.minion_attack("hunter", state.toolLevels.sword).range, true))
	for barbarian in state.barbarians:
		if not barbarian.isAlive:
			continue
		var detected: Array = state.units.filter(func(unit): return Geo.distance(unit.position, barbarian.position) <= 18.0)
		detected.sort_custom(func(a, b): return a.id < b.id)
		if detected.is_empty():
			barbarian.alertedUnitIds = []
			barbarian.alertSoundedThisEncounter = false
		for unit in detected:
			var minion_key: String = "minion:" + unit.id
			if minion_key not in barbarian.alertedUnitIds:
				barbarian.alertedUnitIds.append(minion_key)
				var sound: bool = not barbarian.alertSoundedThisEncounter
				barbarian.alertSoundedThisEncounter = true
				Survival.record_alert(state, "minion", unit.id, unit.position, sound)
			var barbarian_key: String = "barbarian:" + unit.id
			if Geo.distance(unit.position, barbarian.position) <= 15.0 and barbarian_key not in barbarian.alertedUnitIds:
				barbarian.alertedUnitIds.append(barbarian_key)
				Survival.record_alert(state, "barbarian", barbarian.id, barbarian.position, false)
	for unit in state.units:
		var stats: Variant = Combat.minion_attack(unit.role, state.toolLevels.sword)
		if moving:
			var current: Variant = _living(state.barbarians, unit.task.get("targetEntityId"))
			if unit.task.kind == "combat" and current != null and stats != null and Geo.distance(unit.position, current.position) <= stats.range + 1e-6:
				unit.withdrawAfterAttack = true
			elif unit.task.kind in ["combat", "flee", "hunt"]:
				Work.set_task(unit, Work.return_task(state, unit, "totem-moved"))
			continue
		unit.withdrawAfterAttack = false
		var call: Dictionary = calls.get(unit.id, {})
		var threat: Variant = _nearest(unit.position, state.barbarians, 18.0)
		if threat == null and call.get("kind") == "combat":
			threat = _living(state.barbarians, call.targetId)
		if stats != null and threat != null:
			var target: Variant = _choose_combat_target(state, unit)
			Work.set_task(unit, _entity_task("combat", "threat-nearby", target.id if target != null else threat.id))
			continue
		if stats == null and threat != null and Geo.distance(unit.position, threat.position) <= 15.0:
			Work.set_task(unit, _entity_task("flee", "threat-nearby", threat.id))
			continue
		if unit.task.kind in ["flee", "combat"]:
			Work.set_task(unit, Rules.idle_task("combat-ended"))
		if not state.totem.moving and unit.role == "hunter":
			var current: Variant = _living(state.animals, unit.task.get("targetEntityId"))
			var called: Variant = _living(state.animals, call.targetId) if call.get("kind") == "hunt" else null
			var rabbit: Variant = current if current != null and (Geo.distance(unit.position, current.position) <= maxf(state.totem.commandRadius, 0) * 1.05 + 2.0 or (called != null and current.id == called.id)) else _nearest(unit.position, state.animals, maxf(state.totem.commandRadius, 0) * 1.05)
			if rabbit == null:
				rabbit = called
			if rabbit != null:
				Work.set_task(unit, _entity_task("hunt", "animal-found", rabbit.id))
				continue
		if unit.task.kind == "hunt":
			Work.set_task(unit, Rules.idle_task())
	_reserve_combat(state, frame)
	for unit in state.units:
		if unit.attackLockRemainingSeconds > 0:
			continue
		if unit.task.kind == "flee":
			Move.move_towards(state, unit, Move.approach(unit.position, state.totem.position, 2.02), 10.0 * delta, frame)
			continue
		if unit.task.kind == "combat":
			var target: Variant = _living(state.barbarians, unit.task.get("targetEntityId"))
			var stats: Variant = Combat.minion_attack(unit.role, state.toolLevels.sword)
			if target == null or stats == null:
				Work.set_task(unit, Work.return_task(state, unit, "totem-moved") if moving else Rules.idle_task("combat-ended"))
				continue
			var distance := Geo.distance(unit.position, target.position)
			if unit.withdrawAfterAttack:
				if distance > stats.range + 1e-6:
					Work.set_task(unit, Work.return_task(state, unit, "totem-moved"))
					continue
				if unit.attackCooldownRemainingSeconds <= 1e-9:
					_attack(state, unit, target, stats, "barbarian")
					Work.set_task(unit, Work.return_task(state, unit, "totem-moved"))
				continue
			var slot: Dictionary = frame.combatPositions.get(unit.id, unit.position)
			if Geo.distance(unit.position, slot) > 0.025:
				Move.move_towards(state, unit, slot, 6.0 * delta, frame)
			if Geo.distance(unit.position, slot) <= 0.15 and Geo.distance(unit.position, target.position) <= stats.range + 1e-6 and (unit.role != "hunter" or Geo.distance(unit.position, target.position) >= stats.range - 0.6) and unit.attackCooldownRemainingSeconds <= 1e-9:
				_attack(state, unit, target, stats, "barbarian")
			continue
		if unit.task.kind == "hunt":
			var target: Variant = _living(state.animals, unit.task.get("targetEntityId"))
			if target == null:
				Work.set_task(unit, Work.return_task(state, unit, "totem-moved") if moving else Rules.idle_task("action-complete"))
				continue
			if Geo.distance(unit.position, target.position) > 5.0:
				Move.move_towards(state, unit, Move.approach(unit.position, target.position, 5.0), 6.0 * delta, frame)
			if Geo.distance(unit.position, target.position) <= 5.0 + 1e-6 and unit.attackCooldownRemainingSeconds <= 1e-9:
				_attack(state, unit, target, Combat.ANIMAL_ATTACK, "animal")
	for barbarian in state.barbarians:
		if barbarian.isAlive:
			_update_barbarian(state, barbarian, delta, frame)

static func _update_barbarian(state: Dictionary, barbarian: Dictionary, delta: float, frame: Dictionary) -> void:
	var had_target: bool = barbarian.targetUnitId != null
	var target: Variant = _nearest(barbarian.position, state.units, 15.0, false)
	barbarian.targetUnitId = target.id if target != null else null
	if target != null:
		barbarian.returningToSpawn = false
		if Geo.distance(barbarian.position, target.position) > 1.2:
			_move_barbarian(state, barbarian, Move.approach(barbarian.position, target.position, 1.2), 7.0 * delta, frame)
		barbarian.attackProgressSeconds = minf(barbarian.attackProgressSeconds + delta, 2.5)
		if Geo.distance(barbarian.position, target.position) <= 1.2 + 1e-6 and barbarian.attackProgressSeconds + 1e-9 >= 2.5:
			barbarian.attackProgressSeconds = 0.0
			Survival.add_effect(state, "attack-lunge", barbarian.id, target.position, 0.22)
			Survival.damage_unit(state, target.id, 1.0, "barbarian")
		return
	if barbarian.returningToSpawn or (had_target and Geo.distance(barbarian.position, barbarian.spawnPosition) > 0.25):
		barbarian.returningToSpawn = true
		if _move_barbarian(state, barbarian, barbarian.spawnPosition, 8.0 * delta, frame):
			barbarian.returningToSpawn = false
			barbarian.patrolTarget = barbarian.spawnPosition.duplicate()
			barbarian.patrolStep = 0
			barbarian.patrolWaitRemainingSeconds = _patrol_wait(state, barbarian, barbarian.spawnCycle)
		return
	if barbarian.patrolWaitRemainingSeconds > 0:
		barbarian.patrolWaitRemainingSeconds = maxf(barbarian.patrolWaitRemainingSeconds - delta, 0)
		if barbarian.patrolWaitRemainingSeconds > 0:
			return
		barbarian.patrolTarget = _patrol_point(state.seed, barbarian.id, barbarian.spawnCycle, barbarian.patrolStep, barbarian.patrolCenter, barbarian.patrolRadius)
		barbarian.patrolStep += 1
	if Geo.distance(barbarian.position, barbarian.patrolTarget) <= 0.25:
		barbarian.patrolWaitRemainingSeconds = _patrol_wait(state, barbarian, barbarian.spawnCycle)
		return
	if _move_barbarian(state, barbarian, barbarian.patrolTarget, delta, frame):
		barbarian.patrolWaitRemainingSeconds = _patrol_wait(state, barbarian, barbarian.spawnCycle)
