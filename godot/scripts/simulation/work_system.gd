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
const Progression = preload("res://scripts/simulation/progression.gd")

static func set_task(unit: Dictionary, task: Dictionary) -> void:
	if unit.task.kind != task.kind or unit.task.get("targetEntityId", "__undefined") != task.get("targetEntityId", "__undefined") or unit.task.targetResourceId != task.targetResourceId:
		unit.erase("navigation")
	if task.kind != "idle" or unit.task.kind != "idle":
		Move.cancel_idle(unit)
	unit.task = task
	unit.actionProgressSeconds = 0.0
	if task.kind != "combat":
		unit.withdrawAfterAttack = false
	if task.kind in ["gather", "collect-drop"] and task.targetResourceId != unit.cancelledTargetId:
		unit.cancelledTargetId = null
	unit.state = {"gather": "seeking-task", "collect-drop": "collecting-drop", "combat": "combat", "flee": "fleeing", "loot-corpse": "looting-corpse", "hunt": "hunting", "return-to-totem": "returning-to-totem"}.get(task.kind, "idle")

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
	var radius_squared: float = pow(maxf(state.totem.commandRadius, 0) * 1.05, 2)
	var reserved := reserved_targets(state, caller, "gather")
	var nearby: Array = []
	for resource in state.resources:
		var dx: float = resource.position.x - caller.position.x
		var dy: float = resource.position.y - caller.position.y
		if resource.amount > 0 and not Rules.can_gather(caller.role, resource, state.toolLevels) and resource.id != caller.cancelledTargetId and not (caller.task.kind == "gather" and caller.task.targetResourceId == resource.id) and resource.id not in reserved and dx * dx + dy * dy <= radius_squared:
			nearby.append(resource)
	_sort_nearest(nearby, caller.position)
	for resource in nearby:
		var responders: Array = []
		for candidate in state.units:
			if candidate.id != caller.id and candidate.task.kind in ["idle", "return-to-totem"] and Rules.total_amount(candidate.cargo.amounts) == 0 and candidate.cancelledTargetId != resource.id and Rules.can_gather(candidate.role, resource, state.toolLevels):
				responders.append(candidate)
		_sort_nearest(responders, resource.position)
		if not responders.is_empty():
			set_task(responders[0], {"kind": "gather", "targetResourceId": resource.id, "destination": resource.position.duplicate(), "cause": "resource-call-received"})
			return true
	return false

static func drop_resource(state: Dictionary, point: Dictionary, unit_id: String, source_id: Variant, resource_type: String, amount: float) -> void:
	for index in maxi(int(floor(amount)), 0):
		var source_text: String = str(source_id) if source_id != null else "free"
		var random := Random.new("%s:drop:%s:%s:%s:%s" % [state.seed, state.tick, unit_id, source_text, resource_type])
		var angle := random.next_float(0, PI * 2.0) + index * 2.399963229728653
		var position := State.clamp_position({"x": point.x + cos(angle) * 1.5, "y": point.y + sin(angle) * 1.5})
		state.drops.append({"id": "drop-%05d" % state.nextDropId, "type": resource_type, "sourceNodeId": source_id, "position": position, "amount": 1})
		state.nextDropId += 1

static func drop_cargo(state: Dictionary, unit: Dictionary, point: Dictionary, source_id: Variant) -> void:
	for resource_type in Economy.RESOURCE_TYPES:
		drop_resource(state, point, unit.id, source_id, resource_type, unit.cargo.amounts[resource_type])
	unit.cargo.amounts = State.empty_amounts()
	set_task(unit, Rules.idle_task("cargo-dropped"))

static func return_task(state: Dictionary, unit: Dictionary, cause: String) -> Dictionary:
	return {"kind": "return-to-totem", "targetResourceId": null, "destination": Idle.range_entry(unit.position, Move.area(state)), "cause": cause}

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

static func update_unit(state: Dictionary, unit: Dictionary, delta: float, frame: Dictionary) -> void:
	if unit.role == "hunter" and unit.attackLockRemainingSeconds > 0:
		return
	if unit.task.kind == "idle":
		if Rules.total_amount(unit.cargo.amounts) > 0:
			drop_cargo(state, unit, unit.position, null)
			return
		var gather_task := Rules.choose_gather_task({"role": unit.role, "unitPosition": unit.position, "totemPosition": state.totem.position, "commandRadius": state.totem.commandRadius, "cargo": unit.cargo, "resources": state.resources, "toolLevels": state.toolLevels, "reservedTargetIds": reserved_targets(state, unit, "gather"), "excludedTargetId": unit.cancelledTargetId})
		var corpse_task: Variant = _corpse_task(state, unit)
		if corpse_task != null:
			set_task(unit, corpse_task)
			return
		if gather_task.kind == "gather":
			set_task(unit, gather_task)
			return
		var drop_task := Rules.choose_drop_task({"unitPosition": unit.position, "drops": state.drops, "commandRadius": state.totem.commandRadius, "reservedTargetIds": reserved_targets(state, unit, "collect-drop"), "excludedTargetId": unit.cancelledTargetId})
		if drop_task.kind == "collect-drop":
			set_task(unit, drop_task)
			return
		set_task(unit, gather_task)
		if not Idle.within_range(unit.position, Move.area(state)):
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
		if not Move.move_towards(state, unit, Move.resource_approach(unit.position, resource), Move.UNIT_SPEED * delta, frame):
			unit.state = "seeking-task"
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
		drop_resource(state, resource.position, unit.id, resource.id, resource.type, resource.get("yieldAmount", gathered.gathered) + bonus)
		if gathered.gathered > 0:
			Progression.award_experience(state.progression, 1)
		set_task(unit, Rules.idle_task("action-complete"))
		return
	if unit.task.kind == "collect-drop":
		var drop: Variant = Move.find_entity(state.drops, unit.task.targetResourceId)
		if drop == null or drop.amount <= 0:
			set_task(unit, Rules.idle_task("drop-empty"))
			return
		if not Move.move_towards(state, unit, drop.position, Move.UNIT_SPEED * delta, frame):
			unit.state = "collecting-drop"
			return
		state.inventory.amounts = Rules.collect_drop(drop, state.inventory.amounts).inventory
		state.drops = state.drops.filter(func(candidate): return candidate.id != drop.id)
		set_task(unit, Rules.idle_task("drop-collected"))
		return
	if unit.task.kind == "return-to-totem":
		if not Idle.within_range(unit.position, Move.area(state)):
			unit.task.destination = Idle.range_entry(unit.position, Move.area(state))
			Move.move_towards(state, unit, unit.task.destination, Move.RETURN_SPEED * delta, frame)
			if not Idle.within_range(unit.position, Move.area(state)):
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
		if unit.task.kind in ["combat", "flee", "hunt"]:
			all_in_formation = false
			continue
		if state.totem.isCarried or state.totem.moving:
			if unit.task.kind in ["gather", "collect-drop", "loot-corpse"]:
				unit.cancelledTargetId = unit.task.targetResourceId
				unit.actionProgressSeconds = 0.0
			if Rules.total_amount(unit.cargo.amounts) > 0:
				var resource: Variant = Move.find_entity(state.resources, unit.task.targetResourceId)
				drop_cargo(state, unit, unit.position, resource.id if resource != null else null)
			Move.cancel_idle(unit)
			var target := Move.formation_target(state, index)
			var reached := Move.move_towards(state, unit, target, Move.FOLLOW_SPEED * delta, frame)
			var in_formation := reached or Geo.distance(unit.position, target) <= Move.FORMATION_TOLERANCE
			unit.state = "formation" if not state.totem.isCarried and in_formation else "follow-totem"
			unit.task = Rules.idle_task("totem-moved")
			if not in_formation:
				all_in_formation = false
		else:
			update_unit(state, unit, delta, frame)
	if not state.totem.isCarried and state.totem.moving and all_in_formation:
		state.totem.moving = false
		for unit in state.units:
			unit.cancelledTargetId = null
