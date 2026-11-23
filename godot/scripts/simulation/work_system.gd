class_name TribeWorkSystem
extends RefCounted
## Task selection, calls, transactional gathering and physical unit drops.

const Rules = preload("res://scripts/simulation/survival_rules.gd")
const Move = preload("res://scripts/simulation/minion_movement.gd")
const Idle = preload("res://scripts/simulation/minion_idle.gd")
const State = preload("res://scripts/simulation/game_state.gd")
const Geo = preload("res://scripts/simulation/geometry.gd")
const Random = preload("res://scripts/simulation/seeded_random.gd")
const Economy = preload("res://scripts/simulation/economy.gd")
const Combat = preload("res://scripts/simulation/combat_rules.gd")
const Progression = preload("res://scripts/simulation/progression.gd")

const POST_COMBAT_PICKUP_TICKS := 40 # Two seconds at the simulation's 20 Hz.

static func blocks_combat_pickup(role: String, kind: String) -> bool:
	# Ranged units keep attacking their pursuer between evasive movements.
	return kind == "combat" or (kind == "flee" and Combat.is_ranged(role, 1))

static func set_task(unit: Dictionary, task: Dictionary) -> void:
	if blocks_combat_pickup(unit.role, unit.task.kind) and not blocks_combat_pickup(unit.role, task.kind):
		unit.pickupLockTicks = POST_COMBAT_PICKUP_TICKS
	if task.kind != "flee":
		unit.erase("fleeMemory")
	var entry_speed := 0.0
	if task.kind == "combat" and unit.task.kind != "combat" and unit.state == "follow-totem":
		entry_speed = Geo.length(unit.get("navigation", {}).get("velocity", {"x": 0.0, "y": 0.0}))
	if unit.task.kind != task.kind or unit.task.get("targetEntityId", "__undefined") != task.get("targetEntityId", "__undefined") or unit.task.targetResourceId != task.targetResourceId:
		unit.erase("navigation")
	if entry_speed > Move.UNIT_SPEED:
		unit.navigation = Move.Nav.create_state(unit.position)
		unit.navigation.combatEntrySpeed = minf(entry_speed, Move.FOLLOW_SPEED)
		unit.navigation.combatEntryRemaining = 0.4
	if task.kind != "idle" or unit.task.kind != "idle":
		Move.cancel_idle(unit)
	unit.task = task
	unit.actionProgressSeconds = 0.0
	if task.kind != "combat":
		unit.withdrawAfterAttack = false
	if task.kind in ["gather", "collect-drop"] and task.targetResourceId != unit.cancelledTargetId:
		unit.cancelledTargetId = null
	unit.state = {"gather": "seeking-task", "collect-drop": "collecting-drop", "combat": "combat", "flee": "fleeing", "loot-corpse": "looting-corpse", "hunt": "hunting", "return-to-totem": "returning-to-totem"}.get(task.kind, "idle")
	if task.kind == "avoid-combat":
		unit.state = "avoiding-combat"

static func reserved_targets(state: Dictionary, unit: Dictionary, kind: String) -> Array:
	var result: Array = []
	for other in state.units:
		if other.id != unit.id and other.task.kind == kind and other.task.targetResourceId != null:
			result.append(other.task.targetResourceId)
	return result

static func _sort_nearest(candidates: Array, point: Dictionary) -> void:
	candidates.sort_custom(func(a, b):
		var adx: float = a.position.x - point.x
		var ady: float = a.position.y - point.y
		var bdx: float = b.position.x - point.x
		var bdy: float = b.position.y - point.y
		var difference := adx * adx + ady * ady - (bdx * bdx + bdy * bdy)
		return difference < 0 if difference != 0 else a.id < b.id)

static func dispatch_resource_call(state: Dictionary, caller: Dictionary) -> bool:
	if caller.get("isCarried", false):
		return false
	var radius_squared: float = pow(maxf(state.totem.commandRadius, 0) * 1.05, 2)
	var reserved := reserved_targets(state, caller, "gather")
	var center := Move.activity_center(state,caller)
	var nearby: Array = []
	for resource in state.resources:
		var totem_dx: float = resource.position.x - center.x
		var totem_dy: float = resource.position.y - center.y
		# Shared sightings cannot send responders beyond the totem's work area.
		if totem_dx * totem_dx + totem_dy * totem_dy > radius_squared:
			continue
		var dx: float = resource.position.x - caller.position.x
		var dy: float = resource.position.y - caller.position.y
		if resource.amount > 0 and not Rules.can_gather(caller.role, resource, state.toolLevels) and resource.id != caller.cancelledTargetId and not (caller.task.kind == "gather" and caller.task.targetResourceId == resource.id) and resource.id not in reserved and dx * dx + dy * dy <= radius_squared:
			nearby.append(resource)
	_sort_nearest(nearby, caller.position)
	for resource in nearby:
		var responders: Array = []
		for candidate in state.units:
			if candidate.id != caller.id and not candidate.get("isCarried", false) and not Move.returning_after_drop(state, candidate) and candidate.task.kind in ["idle", "return-to-totem"] and Rules.total_amount(candidate.cargo.amounts) == 0 and candidate.cancelledTargetId != resource.id and Rules.can_gather(candidate.role, resource, state.toolLevels):
				responders.append(candidate)
		_sort_nearest(responders, resource.position)
		for responder in responders:
			var goal := Move.Terrain.work_position(state.get("terrain", []), responder.position, resource)
			if goal.is_empty() or not is_finite(Move.Terrain.route_length(state.get("terrain", []), responder.position, goal)):
				continue
			set_task(responder, {"kind":"gather","targetResourceId":resource.id,"destination":goal,"cause":"resource-call-received"})
			return true
	return false

const DROP_FLIGHT_TICKS := 9
const DROP_FIRST_BOUNCE_TICKS := 4
const DROP_SECOND_BOUNCE_TICKS := 3
const DROP_SETTLE_TICKS := DROP_FLIGHT_TICKS + DROP_FIRST_BOUNCE_TICKS + DROP_SECOND_BOUNCE_TICKS

static func drop_resource(state: Dictionary, point: Dictionary, unit_id: String, source_id: Variant, resource_type: String, amount: float, appearance: String = "") -> void:
	var terrain: Array = state.get("terrain", [])
	for index in maxi(int(floor(amount)), 0):
		var source_text: String = str(source_id) if source_id != null else "free"
		var random := Random.new("%s:drop:%s:%s:%s:%s" % [state.seed, int(state.tick), unit_id, source_text, resource_type])
		var angle := random.next_float(0, PI * 2.0) + index * 2.399963229728653
		var position := {}
		for distance: float in [3.0, 2.0, 1.5]:
			var candidate := State.clamp_position({"x": point.x + cos(angle) * distance, "y": point.y + sin(angle) * distance})
			if Move.Terrain.same_level(terrain, point, candidate) and Move.Terrain.fits(terrain, candidate, 0.32, true) and Move.Terrain.clear(terrain, point, candidate):
				position = candidate
				break
		var origin := point
		if position.is_empty():
			position = Move.Terrain.nearest(terrain, point, 0.32, true)
			if position.is_empty():
				position = State.clamp_position(point)
			origin = position
		var drop := {
			"id": "drop-%05d" % state.nextDropId, "type": resource_type,
			"sourceNodeId": source_id, "position": position, "amount": 1,
			"launchOrigin": origin.duplicate(), "launchTick": state.tick,
		}
		if not appearance.is_empty():
			drop.appearance = appearance
		state.drops.append(drop)
		state.nextDropId += 1

static func drop_cargo(state: Dictionary, unit: Dictionary, point: Dictionary, source_id: Variant) -> void:
	for resource_type in Economy.RESOURCE_TYPES:
		drop_resource(state, point, unit.id, source_id, resource_type, unit.cargo.amounts[resource_type])
	unit.cargo.amounts = State.empty_amounts()
	set_task(unit, Rules.idle_task("cargo-dropped"))

static func return_task(state: Dictionary, unit: Dictionary, cause: String) -> Dictionary:
	return {"kind": "return-to-totem", "targetResourceId": null, "destination": Idle.range_entry(unit.position, Move.area(state,unit)), "cause": cause}

static func finish_combat(state: Dictionary, unit: Dictionary) -> void:
	if not state.totem.isCarried and state.totem.moving:
		unit.postCombatFree = true
	unit.cancelledTargetId = null
	set_task(unit, Rules.idle_task("combat-ended") if Idle.within_range(unit.position, Move.area(state,unit)) else return_task(state, unit, "combat-ended"))

static func _corpse_task(state: Dictionary, unit: Dictionary) -> Variant:
	var reserved: Array = []
	for other in state.units:
		if other.id != unit.id and other.task.kind == "loot-corpse":
			reserved.append(other.task.get("targetEntityId"))
	var candidates: Array = []
	for corpse in state.barbarianCorpses:
		if Rules.total_amount(corpse.loot) > 0 and corpse.id not in reserved and Geo.distance(unit.position, corpse.position) <= maxf(state.totem.commandRadius, 0) * 1.05:
			candidates.append(corpse)
	_sort_nearest(candidates, unit.position)
	if candidates.is_empty():
		return null
	return {"kind": "loot-corpse", "targetEntityId": candidates[0].id, "targetResourceId": null, "destination": null, "cause": "corpse-found"}

static func gather_duration(state: Dictionary, resource: Dictionary) -> float:
	var base := 1.5
	if resource.source == "tree":
		base = 3.0
	elif resource.source == "stone-vein":
		base = 7.0 if resource.get("tier", 1) == 2 else 5.0
	var tool := "axe" if resource.type == "wood" else "hammer" if resource.type == "stone" else ""
	return base / Economy.gather_speed_multiplier(tool, state.toolLevels[tool]) if not tool.is_empty() else base

static func choose_work_task(state: Dictionary, unit: Dictionary) -> Dictionary:
	var gather_task := Rules.choose_gather_task({"role": unit.role, "terrain": state.get("terrain", []), "unitPosition": unit.position, "totemPosition": Move.activity_center(state,unit), "commandRadius": state.totem.commandRadius, "cargo": unit.cargo, "resources": state.resources, "toolLevels": state.toolLevels, "reservedTargetIds": reserved_targets(state, unit, "gather"), "excludedTargetId": unit.cancelledTargetId})
	var corpse_task: Variant = _corpse_task(state, unit)
	if corpse_task != null:
		return corpse_task
	if gather_task.kind == "gather":
		return gather_task
	var drop_task := Rules.choose_drop_task({"terrain": state.get("terrain", []), "unitPosition": unit.position, "drops": state.drops, "commandRadius": state.totem.commandRadius, "reservedTargetIds": reserved_targets(state, unit, "collect-drop"), "excludedTargetId": unit.cancelledTargetId})
	if drop_task.kind == "collect-drop":
		return drop_task
	return gather_task

static func _drop_within_reach(rows: Array, position: Dictionary, drop_position: Dictionary) -> bool:
	return Geo.distance(position, drop_position) <= Move.Terrain.DROP_REACH + Move.FORMATION_TOLERANCE and Move.Terrain.clear(rows, position, drop_position, 0.0)

static func update_unit(state: Dictionary, unit: Dictionary, delta: float, frame: Dictionary) -> void:
	if Combat.is_ranged(unit.role, state.toolLevels.sword) and unit.attackLockRemainingSeconds > 0:
		return
	if unit.task.kind == "idle":
		var rows: Array = state.get("terrain", [])
		var cell := Move.Terrain.cell(unit.position)
		if Move.Terrain.ramp(Move.Terrain.code(rows, cell)):
			var direction: int = unit.get("stairTicket", {}).get("exitDirection", 1)
			var landing := Move.Terrain.center(cell + Vector2i(direction, 0))
			Move.move_towards(state, unit, landing, Move.UNIT_SPEED * delta, frame)
			return
		if Rules.total_amount(unit.cargo.amounts) > 0:
			drop_cargo(state, unit, unit.position, null)
			return
		var task := choose_work_task(state, unit)
		set_task(unit, task)
		if task.kind != "idle": return
		if not Idle.within_range(unit.position, Move.area(state,unit)):
			set_task(unit, return_task(state, unit, "no-valid-resource"))
		else:
			Move.update_idle(state, unit, delta, frame)
		return
	if unit.task.kind == "loot-corpse":
		var corpse: Variant = Move.find_entity(state.barbarianCorpses, unit.task.get("targetEntityId"))
		if corpse == null or Rules.total_amount(corpse.loot) <= 0:
			set_task(unit, Rules.idle_task("corpse-looted"))
			return
		if not Move.move_towards(state, unit, Move.approach(unit.position, corpse.position, 1.25), Move.UNIT_SPEED * delta, frame):
			unit.state = "looting-corpse"
			return
		unit.state = "looting-corpse"
		unit.actionProgressSeconds += delta
		if unit.actionProgressSeconds + 1e-9 < 1.5:
			return
		for resource_type in ["gold", "food", "wood"]:
			drop_resource(state, corpse.position, unit.id, corpse.id, resource_type, corpse.loot[resource_type])
		state.barbarianCorpses = state.barbarianCorpses.filter(func(candidate): return candidate.id != corpse.id)
		set_task(unit, Rules.idle_task("corpse-looted"))
		return
	if unit.task.kind == "gather":
		var resource: Variant = Move.find_entity(state.resources, unit.task.targetResourceId)
		if resource == null or resource.amount <= 0:
			if Rules.total_amount(unit.cargo.amounts) > 0:
				drop_cargo(state, unit, resource.position if resource != null else unit.position, resource.id if resource != null else null)
			else:
				set_task(unit, Rules.idle_task("resource-depleted"))
			return
		var rows: Array = state.get("terrain", [])
		var approach: Dictionary = unit.task.destination if unit.task.destination is Dictionary else {}
		if approach.is_empty() or approach == resource.position or not Move.Terrain.clear(rows, approach, resource.position, 0.0):
			approach = Move.Terrain.work_position(rows, unit.position, resource)
			unit.task.destination = approach
		if approach.is_empty():
			unit.cancelledTargetId = resource.id
			set_task(unit,Rules.idle_task("no-valid-resource"))
			return
		if not Move.move_towards(state, unit, approach, Move.UNIT_SPEED * delta, frame):
			unit.state = "seeking-task"
			return
		if not Move.Terrain.clear(rows, unit.position, resource.position, 0.0):
			return
		unit.state = "gathering"
		unit.actionProgressSeconds += delta
		if unit.actionProgressSeconds < gather_duration(state, resource):
			return
		var gathered := Rules.gather_from_node(resource, 1)
		resource.amount = gathered.node.amount
		var bonus := 0
		if resource.type in ["wood", "stone"]:
			var tool := "axe" if resource.type == "wood" else "hammer"
			bonus = 1 if Economy.rolls_bonus(state.seed, state.tick, unit.id, resource.id, tool, state.toolLevels[tool]) else 0
		var appearance := "berries" if resource.source == "berry-bush" else ""
		drop_resource(state, resource.position, unit.id, resource.id, resource.type, gathered.gathered + bonus, appearance)
		if gathered.gathered > 0:
			Progression.award_experience(state.progression, 1)
		set_task(unit, Rules.idle_task("action-complete"))
		return
	if unit.task.kind == "collect-drop":
		var drop: Variant = Move.find_entity(state.drops, unit.task.targetResourceId)
		if drop == null or drop.amount <= 0:
			set_task(unit, Rules.idle_task("drop-empty"))
			return
		var rows: Array = state.get("terrain", [])
		if not _drop_within_reach(rows, unit.position, drop.position):
			var destination: Dictionary = unit.task.destination if unit.task.destination is Dictionary else {}
			if destination.is_empty() or not unit.has("navigation") or not Move.Terrain.valid_drop_position(rows, destination, drop.position):
				destination = Move.Terrain.drop_position(rows, unit.position, drop.position)
				if destination.is_empty() or not is_finite(Move.Terrain.route_length(rows, unit.position, destination)):
					set_task(unit, Rules.idle_task("no-valid-resource"))
					return
				unit.task.destination = destination.duplicate()
			Move.move_towards(state, unit, destination, Move.UNIT_SPEED * delta, frame)
			if not _drop_within_reach(rows, unit.position, drop.position):
				unit.state = "collecting-drop"
				return
		if state.tick < drop.get("launchTick", state.tick - DROP_SETTLE_TICKS) + DROP_SETTLE_TICKS:
			unit.state = "collecting-drop"
			return
		state.inventory.amounts = Rules.collect_drop(drop, state.inventory.amounts).inventory
		state.drops = state.drops.filter(func(candidate): return candidate.id != drop.id)
		set_task(unit, Rules.idle_task("drop-collected"))
		return
	if unit.task.kind == "return-to-totem":
		if not Idle.within_range(unit.position, Move.area(state,unit)):
			unit.task.destination = Idle.range_entry(unit.position, Move.area(state,unit))
			Move.move_towards(state, unit, unit.task.destination, Move.RETURN_SPEED * delta, frame)
			if not Idle.within_range(unit.position, Move.area(state,unit)):
				unit.state = "returning-to-totem"
				return
		set_task(unit, Rules.idle_task("action-complete"))

static func update_tribe(state: Dictionary, delta: float, frame: Dictionary) -> void:
	if not state.totem.isCarried and not state.totem.moving:
		for caller in state.units:
			dispatch_resource_call(state, caller)
	var all_in_formation := true
	for index in state.units.size():
		var unit: Dictionary = state.units[index]
		if unit.get("isCarried", false):
			continue
		if unit.task.kind in ["combat", "flee", "hunt", "avoid-combat"]:
			if state.totem.isCarried:
				all_in_formation = false
			continue
		if not state.totem.isCarried and unit.get("postCombatFree", false):
			update_unit(state, unit, delta, frame)
			continue
		if state.totem.isCarried or state.totem.moving:
			if unit.task.kind in ["gather", "collect-drop", "loot-corpse"]:
				unit.cancelledTargetId = unit.task.targetResourceId
				unit.actionProgressSeconds = 0.0
			if Rules.total_amount(unit.cargo.amounts) > 0:
				var resource: Variant = Move.find_entity(state.resources, unit.task.targetResourceId)
				drop_cargo(state, unit, unit.position, resource.id if resource != null else null)
			Move.cancel_idle(unit)
			var follow: Dictionary = frame.followers.get(unit.id,{})
			if follow.is_empty():
				all_in_formation = false
				continue
			var target: Dictionary = follow.target
			var reached: bool = not follow.available or Move.move_towards(state, unit, target, follow.speed * delta, frame)
			var in_formation := reached or Geo.distance(unit.position, target) <= Move.FORMATION_TOLERANCE
			unit.state = "formation" if not state.totem.isCarried and in_formation else "follow-totem"
			unit.task = Rules.idle_task("totem-moved")
			if not state.totem.isCarried and in_formation and not Idle.within_range(unit.position, Move.area(state)):
				unit.formationActivityCenter = unit.position.duplicate()
			elif in_formation:
				unit.erase("formationActivityCenter")
			if not in_formation:
				all_in_formation = false
		else:
			update_unit(state, unit, delta, frame)
	if not state.totem.isCarried and state.totem.moving and all_in_formation:
		state.totem.moving = false
		for unit in state.units:
			unit.cancelledTargetId = null
			unit.erase("postCombatFree")
