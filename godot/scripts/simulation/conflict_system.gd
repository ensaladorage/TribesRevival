class_name TribeConflictSystem
extends RefCounted
## Combat, fauna, respawn and loot. Rendering never decides hits or targets.

const Tactics = preload("res://scripts/simulation/tactical_movement.gd")
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
	barbarian.respawnRemainingSeconds = 180.0
	barbarian.targetUnitId = null
	state.alerts = state.alerts.filter(func(alert): return alert.detectorKind != "barbarian" or alert.detectorId != barbarian.id)
	var random := Random.new("%s:barbarian-loot:%s:%s" % [state.seed, barbarian.id, barbarian.spawnCycle])
	var loot := State.empty_amounts()
	loot.gold = random.next_int(1, 2)
	loot.food = random.next_int(0, 2)
	loot.wood = random.next_int(0, 1)
	state.barbarianCorpses.append({"id": "corpse-%s-%s" % [barbarian.id, barbarian.spawnCycle], "barbarianId": barbarian.id, "position": barbarian.position.duplicate(), "loot": loot})

# At 20 Hz the sixth frame of the 10 FPS draw starts after ten ticks.
const HUNTER_DRAW_TICKS := 10
const HUNTER_FLIGHT_TICKS := 5
const HUNTER_ATTACK_TICKS := 16
const HUNTER_HIT_RADIUS := 0.47

static func _attack(state: Dictionary, unit: Dictionary, target: Dictionary, stats: Dictionary, kind: String) -> bool:
	if not Combat.is_ranged(unit.role,state.toolLevels.sword) and not Move.Terrain.clear(state.get("terrain",[]),unit.position,target.position):
		return false
	unit.attackCooldownRemainingSeconds = stats.cooldownSeconds
	if unit.role == "hunter":
		# Hold the archer in place while drawing the bow.
		unit.attackLockRemainingSeconds = 0.5
		if not state.has("hunterShots"):
			state.hunterShots = []
		var release_tick: int = int(state.tick) + HUNTER_DRAW_TICKS
		state.hunterShots.append({
			"id": "hunter-shot-%d" % state.nextEffectId,
			"hunterId": unit.id,
			"targetId": target.id,
			"targetKind": kind,
			"targetSpawnCycle": target.spawnCycle,
			"damage": stats.damage,
			"startTick": state.tick,
			"releaseTick": release_tick,
			"impactTick": release_tick + HUNTER_FLIGHT_TICKS,
			"aim": target.position.duplicate(),
		})
		state.nextEffectId += 1
		return false
	unit.attackLockRemainingSeconds = 0.22
	Survival.add_effect(state, "attack-lunge", unit.id, target.position, 0.22)
	return _apply_attack_damage(state, unit, target, stats.damage, kind)

static func _apply_attack_damage(state: Dictionary, unit: Variant, target: Dictionary, damage: float, kind: String) -> bool:
	var result := Combat.deal_damage("minion", kind, target, damage)
	target.health = result.health
	if kind == "barbarian" and result.damageApplied > 0:
		Survival.add_effect(state, "damage-flash", target.id, target.position, 0.3)
		var prey: Variant = Move.find_entity(state.units, target.targetUnitId)
		if unit != null and unit.health > 0 and not unit.get("isCarried", false) and not result.defeated and prey != null and (Combat.minion_attack(prey.role, state.toolLevels.sword) == null or (Combat.is_ranged(prey.role, state.toolLevels.sword) and Combat.is_melee(unit.role, state.toolLevels.sword))) and Combat.minion_attack(unit.role, state.toolLevels.sword) != null:
			# Only a landed hit can pull a barbarian off civilian prey.
			# Melee can also relieve ranged prey; a melee focus stays stable.
			target.targetUnitId = unit.id
	if result.defeated:
		if kind == "barbarian":
			_defeat_barbarian(state, target)
		elif target.isAlive:
			Progression.award_experience(state.progression, 3)
			target.health = 0.0
			target.isAlive = false
			target.respawnRemainingSeconds = 90.0
			var random := Random.new("%s:rabbit-loot:%s:%s" % [state.seed, target.id, target.spawnCycle])
			Work.drop_resource(state, target.position, target.id, target.id, "food", random.next_int(1, 2))
	return result.defeated

static func update_hunter_shots(state: Dictionary) -> void:
	if not state.has("hunterShots"):
		return
	var pending: Array = []
	for shot: Dictionary in state.hunterShots:
		if state.tick >= shot.startTick + HUNTER_ATTACK_TICKS:
			continue
		if shot.get("resolved", false):
			pending.append(shot)
			continue
		var hunter: Variant = Move.find_entity(state.units, shot.hunterId)
		var candidates: Array = state.animals if shot.targetKind == "animal" else state.barbarians
		var target: Variant = _living(candidates, shot.targetId)
		if target != null and target.spawnCycle != shot.targetSpawnCycle:
			target = null
		if not shot.has("origin"):
			if hunter == null or hunter.health <= 0 or hunter.role != "hunter" or hunter.get("isCarried", false) or target == null:
				continue
			shot.aim = target.position.duplicate()
			if state.tick >= shot.releaseTick:
				shot.origin = hunter.position.duplicate()
		if state.tick >= shot.impactTick:
			var hit: bool = target != null and Geo.distance(target.position, shot.aim) <= HUNTER_HIT_RADIUS
			if hit:
				_apply_attack_damage(state, hunter, target, shot.damage, shot.targetKind)
			Survival.add_effect(state, "hunter-impact" if hit else "hunter-miss", shot.targetId, shot.aim, 0.3)
			shot.resolved = true
		pending.append(shot)
	if pending.is_empty():
		state.erase("hunterShots")
	else:
		state.hunterShots = pending

const SHEEP_PATROL_TICKS := 160
const SHEEP_REST_TICKS := 20
const SHEEP_GRAZE_TICKS := 24

static func _sheep_is_patrolling(state: Dictionary, animal: Dictionary) -> bool:
	var tick: int = state.tick
	if not animal.has("grazingCycle"):
		var random := Random.new("%s:%s:grazing:%d" % [state.seed, animal.id, animal.spawnCycle])
		animal.grazingCycle = {"phase": "patrol", "startTick": tick, "nextTick": tick + SHEEP_PATROL_TICKS + random.next_int(0, 20)}
	var cycle: Dictionary = animal.grazingCycle
	if tick >= cycle.nextTick:
		match cycle.phase:
			"patrol":
				cycle = {"phase": "rest", "startTick": tick, "nextTick": tick + SHEEP_REST_TICKS}
			"rest":
				cycle = {"phase": "graze", "startTick": tick, "nextTick": tick + SHEEP_GRAZE_TICKS}
			"graze":
				cycle = {"phase": "patrol", "startTick": tick, "nextTick": tick + SHEEP_PATROL_TICKS}
		animal.grazingCycle = cycle
	return cycle.phase == "patrol"

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
		var region: Dictionary = {}
		for biome in state.biomes:
			if biome.instanceId == animal.get("homeBiomeId",""):
				region = biome.region
				break
		if not animal.isAlive:
			animal.respawnRemainingSeconds = maxf(animal.respawnRemainingSeconds - delta, 0)
			if animal.respawnRemainingSeconds < 1e-9:
				animal.respawnRemainingSeconds = 0.0
			if animal.respawnRemainingSeconds > 0:
				continue
			animal.isAlive = true
			animal.health = animal.maxHealth
			animal.position = animal.spawnPosition.duplicate()
			animal.patrolTarget = _animal_target(state,animal,region,animal.spawnCycle + 1,animal.spawnCycle + 1)
			animal.erase("terrainRoute")
			animal.spawnCycle += 1
			animal.erase("grazingCycle")
			continue
		if not _sheep_is_patrolling(state, animal):
			continue
		if Geo.distance(animal.position, animal.patrolTarget) <= 0.2:
			animal.patrolTarget = _animal_target(state,animal,region,animal.spawnCycle,state.tick)
		if region.is_empty():
			Weather.move_point(animal.position, animal.patrolTarget, 1.2 * delta)
			continue
		var rows := Move.Terrain.meadow_rows(region, state.terrain)
		var goal := Move.Terrain.waypoint(rows, animal.position, animal.patrolTarget, animal)
		var next: Dictionary = animal.position.duplicate()
		Weather.move_point(next, goal, 1.2 * delta)
		if next != animal.position and Move.Terrain.clear(rows, animal.position, next):
			animal.position = next
		else:
			animal.erase("terrainRoute")
			animal.patrolTarget = animal.position.duplicate()

static func _animal_target(state: Dictionary, animal: Dictionary, region: Dictionary, cycle: int, step: int) -> Dictionary:
	if region.is_empty():
		return _patrol_point(state.seed,animal.id,cycle,step,animal.homeCenter,animal.homeRadius)
	var random := Random.new("%s:%s:patrol:%d:%d" % [state.seed,animal.id,cycle,step])
	return State.Catalog.Footprint.sample(region,random,region.spawnCells)

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
			descriptors.append({"id": unit.id, "position": unit.position, "range": Combat.minion_attack(unit.role, state.toolLevels.sword).range, "ranged": Combat.is_ranged(unit.role, state.toolLevels.sword), "offset": memory.get("combatOffset") if memory.get("combatTargetId") == target.id else null})
		var allowed := func(attacker: Dictionary, point: Dictionary) -> bool:
			if point.x < 2 or point.y < 2 or point.x > 158 or point.y > 158 or Geo.distance(point, state.totem.position) < 2.02:
				return false
			if not Move.Terrain.fits(state.get("terrain",[]),point) or (not attacker.ranged and not Move.Terrain.clear(state.get("terrain",[]),point,target.position)):
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
		if unit.get("isCarried", false):
			continue
		var origin: Dictionary = frame.origins.get(unit.id, unit.position)
		var velocity: Dictionary = frame.reservations.get(unit.id, {}).get("tickVelocity", zero)
		neighbors.append({"id": unit.id, "position": origin, "velocity": velocity, "tickVelocity": velocity, "stopAfterSeconds": frame.deltaSeconds, "fixed": true, "priority": 4})
	for other in state.barbarians:
		if other.isAlive and other.id != barbarian.id:
			neighbors.append({"id": other.id, "position": other.position, "velocity": zero, "tickVelocity": zero, "stopAfterSeconds": 0.0, "fixed": true, "priority": 4})
	var safe_destination := Move.outside_totem(destination, state.totem.position, barbarian.id)
	var rows: Array = state.get("terrain",[])
	safe_destination = Move.Terrain.nearest(rows,safe_destination)
	var steering_destination := Move.Terrain.waypoint(rows,barbarian.position,safe_destination,barbarian)
	steering_destination = Move.Terrain.stair_waypoint(state, barbarian, steering_destination)
	# Unlike minions, barbarians cannot cross the totem's clearance. Local
	# +/-75 degree avoidance alone stalls on its near side: steer around it.
	if not Nav.segment_is_clear(barbarian.position, steering_destination, [{"position": state.totem.position}], Move.TOTEM_CLEARANCE):
		var center: Dictionary = state.totem.position
		var angle := atan2(barbarian.position.y - center.y, barbarian.position.x - center.x)
		var origin_angle := angle
		if Geo.distance(barbarian.position, center) >= Move.TOTEM_CLEARANCE + 0.05:
			var target_angle := atan2(safe_destination.y - center.y, safe_destination.x - center.x)
			var turn := wrapf(target_angle - angle, -PI, PI)
			angle += (1.0 if turn >= 0 else -1.0) * PI / 4.0
		var radius := Move.TOTEM_CLEARANCE + 0.4
		for candidate_angle in [angle, origin_angle - (angle - origin_angle), origin_angle + PI / 2.0, origin_angle - PI / 2.0]:
			var point := {"x": center.x + cos(candidate_angle) * radius, "y": center.y + sin(candidate_angle) * radius}
			if point.x >= 2 and point.y >= 2 and point.x <= 158 and point.y <= 158:
				steering_destination = point
				break
	var minimum_clearance := minf(Move.TOTEM_CLEARANCE, Geo.distance(barbarian.position, state.totem.position))
	var input := {"agent": {"id": barbarian.id, "position": barbarian.position, "velocity": zero, "tickVelocity": zero, "stopAfterSeconds": 0.0, "fixed": false, "priority": 2}, "destination": steering_destination, "speed": distance / frame.deltaSeconds, "deltaSeconds": frame.deltaSeconds, "neighbors": neighbors}
	var result := Nav.choose_step(input, func(point): return Move.Terrain.clear(rows,barbarian.position,point) and point.x >= 2 and point.y >= 2 and point.x <= 158 and point.y <= 158 and Geo.distance(point, state.totem.position) >= minimum_clearance - 1e-8)
	barbarian.position.merge(result.position, true)
	return Geo.distance(barbarian.position, safe_destination) <= 0.08

static func update(state: Dictionary, delta: float, frame: Dictionary) -> void:
	_update_respawns_and_fauna(state, delta)
	var moving: bool = state.totem.isCarried or state.totem.moving
	var units: Array = []
	for unit in state.units:
		if unit.get("isCarried", false):
			continue
		units.append({"id": unit.id, "position": unit.position, "currentKind": unit.task.kind, "currentTargetId": unit.task.get("targetEntityId"), "available": not Move.returning_after_drop(state, unit) and unit.task.kind in ["idle", "return-to-totem"] and Rules.total_amount(unit.cargo.amounts) == 0, "canFight": Combat.minion_attack(unit.role, state.toolLevels.sword) != null, "canHunt": unit.role == "hunter", "ranged": Combat.is_ranged(unit.role, state.toolLevels.sword), "attackRange": Combat.minion_attack(unit.role, state.toolLevels.sword).range if Combat.is_ranged(unit.role, state.toolLevels.sword) else 0.0})
	var entities: Array = []
	for entity in state.barbarians + state.animals:
		entities.append({"id": entity.id, "position": entity.position, "isAlive": entity.isAlive, "kind": "hunt" if entity.has("kind") else "combat"})
	var calls: Dictionary = {} if moving else Awareness.choose_calls(units, entities, 18, maxf(state.totem.commandRadius, 0) * 1.05, func(unit, entity): return entity.kind != "combat" or not unit.ranged or Geo.distance(entity.position, state.totem.position) <= minf(state.totem.commandRadius, 10.0) + Slots.position_radius(unit.attackRange, true))
	for barbarian in state.barbarians:
		if not barbarian.isAlive:
			continue
		var detected: Array = state.units.filter(func(unit): return not unit.get("isCarried", false) and Geo.distance(unit.position, barbarian.position) <= 18.0)
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
		if unit.get("isCarried", false):
			continue
		var stats: Variant = Combat.minion_attack(unit.role, state.toolLevels.sword)
		if Move.returning_after_drop(state, unit):
			continue
		if stats == null:
			continue # Resolve armed responses and enemy intent before civilian decisions.
		if Combat.is_ranged(unit.role, state.toolLevels.sword) and state.barbarians.any(func(enemy): return enemy.isAlive and enemy.targetUnitId == unit.id and Geo.distance(unit.position, enemy.position) <= Combat.BARBARIAN_DETECTION_RADIUS):
			continue # Preserve the same flee episode until enemy intent is resolved.
		unit.erase("fleeMemory")
		var following: bool = state.totem.isCarried or (state.totem.moving and not unit.get("postCombatFree", false))
		if following:
			# The fighter's leash takes priority even if the enemy is still in range
			# of the totem. Finish only the active impulse, never start another hit.
			if stats != null and Geo.distance(unit.position, state.totem.position) > state.totem.commandRadius:
				if unit.attackLockRemainingSeconds <= 0:
					Work.set_task(unit, Work.return_task(state, unit, "totem-moved"))
				continue
			# A nearby barbarian takes priority over following, even while carried.
			# Keep the leash local so the tribe does not chase distant enemies.
			var nearby: Variant = _nearest(unit.position, state.barbarians, Combat.MINION_THREAT_DETECTION_RADIUS)
			if nearby != null and Geo.distance(nearby.position, state.totem.position) <= state.totem.commandRadius:
				if stats != null:
					unit.withdrawAfterAttack = false
					Work.set_task(unit, _entity_task("combat", "threat-nearby", nearby.id))
					continue
			var current: Variant = _living(state.barbarians, unit.task.get("targetEntityId"))
			if unit.task.kind == "combat" and current != null and stats != null and Geo.distance(unit.position, current.position) <= stats.range + 1e-6:
				unit.withdrawAfterAttack = true
			elif unit.task.kind == "combat" and current == null and not state.totem.isCarried:
				Work.finish_combat(state, unit)
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
		if unit.task.kind == "combat":
			Work.finish_combat(state, unit)
		elif unit.task.kind == "flee":
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
	retarget_enemies(state)
	for unit in state.units:
		if unit.get("isCarried", false):
			continue
		if not Combat.is_ranged(unit.role, state.toolLevels.sword) and Combat.minion_attack(unit.role, state.toolLevels.sword) != null:
			continue
		var pursuers: Array = state.barbarians.filter(func(enemy): return enemy.isAlive and enemy.targetUnitId == unit.id)
		var pursuer: Variant = _nearest(unit.position, pursuers, INF)
		if pursuer != null:
			Work.set_task(unit, _entity_task("flee", "pursued", pursuer.id))
			Tactics.prepare_flee(state, unit)
			continue
		if Move.returning_after_drop(state, unit):
			continue
		if unit.task.kind == "flee" or (unit.task.kind == "avoid-combat" and (moving or Tactics.combat_area_clear(state, unit.position))):
			Work.set_task(unit, Rules.idle_task("combat-ended"))
		if Combat.is_ranged(unit.role, state.toolLevels.sword):
			continue # Unpursued hunters keep their ranged combat/hunting tasks.
		if not moving and unit.task.kind in ["idle", "avoid-combat"] and Rules.total_amount(unit.cargo.amounts) == 0 and not Tactics.combat_area_clear(state, unit.position):
			var work_task := Work.choose_work_task(state, unit)
			if work_task.kind != "idle": Work.set_task(unit, work_task)
		if not moving and unit.task.kind not in ["gather", "collect-drop", "loot-corpse"] and not Tactics.combat_area_clear(state, unit.position):
			var goal := Tactics.avoid_combat_goal(state, unit)
			Work.set_task(unit, {"kind": "avoid-combat", "cause": "combat-area", "targetResourceId": null, "destination": goal})
	_reserve_combat(state, frame)
	for unit in state.units:
		if unit.get("isCarried", false):
			continue
		if unit.attackLockRemainingSeconds > 0:
			continue
		if unit.task.kind == "flee":
			Tactics.update_flee(state, unit, delta, frame)
			if Combat.is_ranged(unit.role, state.toolLevels.sword) and unit.fleeMemory.phase == "pause" and not unit.fleeMemory.suspended and unit.attackCooldownRemainingSeconds <= 1e-9:
				var target: Variant = _living(state.barbarians, unit.task.get("targetEntityId"))
				var stats: Dictionary = Combat.minion_attack(unit.role, state.toolLevels.sword)
				if target != null and Geo.distance(unit.position, target.position) <= stats.range:
					_attack(state, unit, target, stats, "barbarian")
			continue
		if unit.task.kind == "avoid-combat":
			Move.move_towards(state, unit, unit.task.destination, Move.UNIT_SPEED * delta, frame)
			continue
		if unit.task.kind == "combat":
			var combat_speed := Move.combat_speed(unit)
			if unit.has("navigation") and unit.navigation.has("combatEntryRemaining"):
				unit.navigation.combatEntryRemaining = maxf(0.0, unit.navigation.combatEntryRemaining - delta)
			var target: Variant = _living(state.barbarians, unit.task.get("targetEntityId"))
			var stats: Variant = Combat.minion_attack(unit.role, state.toolLevels.sword)
			if target == null or stats == null:
				if state.totem.isCarried:
					Work.set_task(unit, Work.return_task(state, unit, "totem-moved"))
				else:
					Work.finish_combat(state, unit)
				continue
			var distance := Geo.distance(unit.position, target.position)
			if unit.withdrawAfterAttack:
				if distance > stats.range + 1e-6:
					Work.set_task(unit, Work.return_task(state, unit, "totem-moved"))
					continue
				if unit.attackCooldownRemainingSeconds <= 1e-9:
					var defeated := _attack(state, unit, target, stats, "barbarian")
					if defeated and not state.totem.isCarried:
						Work.finish_combat(state, unit)
					else:
						Work.set_task(unit, Work.return_task(state, unit, "totem-moved"))
				continue
			var slot: Dictionary = frame.combatPositions.get(unit.id, unit.position)
			if Geo.distance(unit.position, slot) > 0.025:
				Move.move_towards(state, unit, slot, combat_speed * delta, frame)
			if Geo.distance(unit.position, slot) <= 0.15 and Geo.distance(unit.position, target.position) <= stats.range + 1e-6 and (not Combat.is_ranged(unit.role, state.toolLevels.sword) or Geo.distance(unit.position, target.position) >= stats.range - 0.6) and unit.attackCooldownRemainingSeconds <= 1e-9:
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
			_update_barbarian(state, barbarian, delta, frame, true)

static func retarget_enemies(state: Dictionary) -> void:
	for barbarian in state.barbarians:
		if barbarian.isAlive:
			var target: Variant = _barbarian_target(state, barbarian)
			if barbarian.targetUnitId != null and target == null:
				barbarian.returningToSpawn = true
			barbarian.targetUnitId = target.id if target != null else null

static func _barbarian_target(state: Dictionary, barbarian: Dictionary) -> Variant:
	# Prefer engaged melee fighters without bouncing between equivalent targets.
	var current: Variant = Move.find_entity(state.units, barbarian.targetUnitId)
	var threats := Tactics.attackers(state, barbarian)
	var rows: Array = state.get("terrain", [])
	var reachable := func(unit: Dictionary) -> bool:
		return is_finite(Move.Terrain.route_length(rows, barbarian.position, unit.position))
	threats = threats.filter(reachable)
	var melee: Array = threats.filter(func(unit): return Combat.is_melee(unit.role, state.toolLevels.sword))
	if current != null and not current.get("isCarried", false) and current.health > 0 and reachable.call(current) and Geo.distance(current.position, barbarian.position) <= Combat.BARBARIAN_DETECTION_RADIUS:
		if Combat.is_ranged(current.role, state.toolLevels.sword) and not melee.is_empty():
			return melee[0]
		return current
	if not melee.is_empty():
		return melee[0]
	return threats[0] if not threats.is_empty() else _nearest(barbarian.position, state.units.filter(func(unit): return unit.health > 0 and not unit.get("isCarried", false) and Geo.distance(unit.position, barbarian.position) <= Combat.BARBARIAN_DETECTION_RADIUS and reachable.call(unit)), Combat.BARBARIAN_DETECTION_RADIUS, false)

static func _update_barbarian(state: Dictionary, barbarian: Dictionary, delta: float, frame: Dictionary, intent_selected: bool = false) -> void:
	var had_target: bool = barbarian.targetUnitId != null or barbarian.returningToSpawn
	var target: Variant = Move.find_entity(state.units, barbarian.targetUnitId) if intent_selected else _barbarian_target(state, barbarian)
	var threats := Tactics.attackers(state, barbarian)
	barbarian.targetUnitId = target.id if target != null else null
	if target != null:
		barbarian.returningToSpawn = false
		if threats.size() >= 2 and barbarian.attackProgressSeconds >= 0.22 and barbarian.attackProgressSeconds < 0.75:
			_move_barbarian(state, barbarian, Tactics.reposition_goal(state, barbarian, target, threats), 7.0 * delta, frame)
		elif not Move.Terrain.clear(state.get("terrain",[]),barbarian.position,target.position):
			_move_barbarian(state,barbarian,target.position,7.0 * delta,frame)
		elif Geo.distance(barbarian.position, target.position) > 1.2:
			_move_barbarian(state, barbarian, Move.approach(barbarian.position, target.position, 1.2), 7.0 * delta, frame)
		barbarian.attackProgressSeconds = minf(barbarian.attackProgressSeconds + delta, 2.5)
		if Geo.distance(barbarian.position, target.position) <= 1.2 + 1e-6 and Move.Terrain.clear(state.get("terrain",[]),barbarian.position,target.position) and barbarian.attackProgressSeconds + 1e-9 >= 2.5:
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
