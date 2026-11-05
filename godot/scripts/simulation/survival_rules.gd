class_name TribeSurvivalRules
extends RefCounted

const Economy = preload("res://scripts/simulation/economy.gd")
const Geo = preload("res://scripts/simulation/geometry.gd")
const AFFINITY := {"explorer": [], "gatherer": ["food"], "lumberjack": ["wood"], "hunter": [], "guardian": [], "artisan": ["stone", "spark"], "mage": []}

static func _whole(amount: float) -> int:
	return maxi(int(floor(amount)), 0) if is_finite(amount) else 0

static func total_amount(amounts: Dictionary) -> int:
	var total := 0
	for amount in amounts.values():
		total += _whole(amount)
	return total

static func count_role(units: Array, role: String) -> int:
	var count := 0
	for unit in units:
		if unit.role == role:
			count += 1
	return count

static func can_convert_last_gatherer(units: Array) -> bool:
	return count_role(units, "gatherer") > 1 or count_role(units, "hunter") > 0

static func can_gather(role: String, node: Dictionary, levels: Dictionary) -> bool:
	var affinity: bool = node.type == "wood" if node.source == "twigs" else node.type in AFFINITY.get(role, [])
	return affinity and Economy.node_tool_requirement_met(node, levels)

static func gather_from_node(node: Dictionary, requested_amount: float) -> Dictionary:
	var gathered := mini(_whole(requested_amount), _whole(node.amount))
	var next := node.duplicate(true)
	next.amount = _whole(node.amount - gathered)
	return {"node": next, "gathered": gathered}

static func add_to_cargo(cargo: Dictionary, resource_type: String, requested_amount: float) -> Dictionary:
	var free_capacity := maxi(cargo.capacity - total_amount(cargo.amounts), 0)
	var accepted := mini(_whole(requested_amount), free_capacity)
	var next := cargo.duplicate(true)
	next.amounts[resource_type] += accepted
	return {"cargo": next, "accepted": accepted}

static func collect_drop(drop: Dictionary, inventory: Dictionary) -> Dictionary:
	var collected := 1 if drop.amount > 0 else 0
	var next := inventory.duplicate()
	next[drop.type] = _whole(next[drop.type]) + collected
	var next_drop := drop.duplicate(true)
	next_drop.amount = 0
	return {"drop": next_drop, "inventory": next, "collected": collected}

static func idle_task(cause: String = "no-valid-resource") -> Dictionary:
	return {"kind": "idle", "cause": cause, "targetResourceId": null, "destination": null}

static func _nearest(candidates: Array, position: Dictionary) -> Variant:
	var ordered := candidates.duplicate()
	ordered.sort_custom(func(a, b):
		var adx: float = position.x - a.position.x
		var ady: float = position.y - a.position.y
		var bdx: float = position.x - b.position.x
		var bdy: float = position.y - b.position.y
		var difference := adx * adx + ady * ady - (bdx * bdx + bdy * bdy)
		return difference < 0 if difference != 0 else a.id < b.id)
	return ordered[0] if not ordered.is_empty() else null

static func _in_detection_range(position: Dictionary, target: Dictionary, command_radius: float) -> bool:
	var dx: float = target.x - position.x
	var dy: float = target.y - position.y
	return dx * dx + dy * dy <= pow(maxf(command_radius, 0) * 1.05, 2)

static func choose_gather_task(input: Dictionary) -> Dictionary:
	if total_amount(input.cargo.amounts) >= input.cargo.capacity:
		return idle_task("over-capacity")
	var candidates: Array = []
	for node in input.resources:
		if node.amount > 0 and can_gather(input.role, node, input.get("toolLevels", {"axe": 0, "hammer": 0, "sword": 0})) and node.id != input.get("excludedTargetId") and node.id not in input.get("reservedTargetIds", []) and _in_detection_range(input.unitPosition, node.position, input.commandRadius):
			candidates.append(node)
	var target: Variant = _nearest(candidates, input.unitPosition)
	if target == null:
		return idle_task()
	return {"kind": "gather", "cause": "resource-found", "targetResourceId": target.id, "destination": target.position}

static func choose_drop_task(input: Dictionary) -> Dictionary:
	var candidates: Array = []
	for drop in input.drops:
		if drop.amount > 0 and drop.id != input.get("excludedTargetId") and drop.id not in input.get("reservedTargetIds", []) and _in_detection_range(input.unitPosition, drop.position, input.commandRadius):
			candidates.append(drop)
	var target: Variant = _nearest(candidates, input.unitPosition)
	if target == null:
		return idle_task()
	return {"kind": "collect-drop", "cause": "drop-found", "targetResourceId": target.id, "destination": target.position}
