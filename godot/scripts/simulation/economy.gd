class_name TribeEconomy
extends RefCounted
## Shared pure economic rules; UI and commands use the same tables.

const Random = preload("res://scripts/simulation/seeded_random.gd")
const MAX_PLAYABLE_MINIONS := 8
const STARTING_MINION_COUNT := 2
const MAX_TOOL_LEVEL := 10
const RESOURCE_TYPES := ["food", "wood", "stone", "spark", "gold"]
const FOOD_COSTS := [2, 3, 3, 4, 4, 4]
const SPECIALIZATION_COSTS := [2, 3, 3, 4, 4]
const SPECIALIZATIONS := {
	"axe": {"resource": "wood", "role": "lumberjack", "limit": 5},
	"bow": {"resource": "wood", "role": "hunter", "limit": 5},
	"hammer": {"resource": "wood", "role": "artisan", "limit": 5},
	"sword": {"resource": "gold", "role": "guardian", "limit": 5},
	"mage": {"resource": "spark", "role": "mage", "limit": 1},
}
const TOOL_COSTS := [{}, {"stone": 1}, {"stone": 2}, {"stone": 3}, {"stone": 4}, {"stone": 5}, {"stone": 6}, {"stone": 7}, {"stone": 8, "spark": 1}, {"stone": 9, "spark": 1, "gold": 1}, {"stone": 10, "spark": 2, "gold": 2}]
const SPEED_PERCENTAGES := [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5]
const BONUS_CHANCES := [0, 0, 0.5, 1, 1.5, 2, 5, 10, 15, 20, 30]

static func recruitment_cost(population: int) -> Dictionary:
	var index := clampi(population - STARTING_MINION_COUNT, 0, FOOD_COSTS.size() - 1)
	return {"food": FOOD_COSTS[index]}

static func specialization_cost(item: String, active_count: int) -> Dictionary:
	if not SPECIALIZATIONS.has(item):
		return {}
	var amount: int = 2 if item == "mage" else SPECIALIZATION_COSTS[clampi(active_count, 0, SPECIALIZATION_COSTS.size() - 1)]
	return {SPECIALIZATIONS[item].resource: amount}

static func shield_cost(equipped_guardians: int) -> Dictionary:
	return {"gold": SPECIALIZATION_COSTS[clampi(equipped_guardians, 0, SPECIALIZATION_COSTS.size() - 1)]}

static func tool_upgrade(tool: String, level: int) -> Variant:
	if tool not in ["axe", "hammer", "sword"] or level < 0 or level > MAX_TOOL_LEVEL:
		return null
	var effect := {"guardianDamageBonus": level * 0.25} if tool == "sword" else {"gatherSpeedPercent": SPEED_PERCENTAGES[level], "bonusResourceChance": BONUS_CHANCES[level]}
	return {"level": level, "cost": TOOL_COSTS[level].duplicate(), "effect": effect}

static func tool_effect(tool: String, level: int) -> Dictionary:
	var upgrade: Variant = tool_upgrade(tool, clampi(level, 0, MAX_TOOL_LEVEL))
	return upgrade.effect if upgrade != null else {}

static func can_afford(amounts: Dictionary, cost: Dictionary) -> bool:
	for resource in cost:
		if amounts[resource] < cost[resource]:
			return false
	return true

static func missing_resources(amounts: Dictionary, cost: Dictionary) -> Dictionary:
	var missing := {}
	for resource in cost:
		var difference := maxf(cost[resource] - amounts[resource], 0)
		if difference > 0:
			missing[resource] = difference
	return missing

static func spend(amounts: Dictionary, cost: Dictionary) -> bool:
	if not can_afford(amounts, cost):
		return false
	for resource in cost:
		amounts[resource] -= cost[resource]
	return true

static func gather_speed_multiplier(tool: String, level: int) -> float:
	return 1.0 + float(tool_effect(tool, level).get("gatherSpeedPercent", 0)) / 100.0

static func rolls_bonus(seed_text: String, tick: int, unit_id: String, node_id: String, tool: String, level: int) -> bool:
	var chance: float = tool_effect(tool, level).get("bonusResourceChance", 0)
	if chance <= 0:
		return false
	var random := Random.new("%s:tool-bonus:%s:%s:%s:%s" % [seed_text, tick, unit_id, node_id, tool])
	return random.next_float() < chance / 100.0

static func node_tool_requirement_met(node: Dictionary, levels: Dictionary) -> bool:
	return node.source != "stone-vein" or node.get("tier", 1) != 2 or levels.hammer >= 5
