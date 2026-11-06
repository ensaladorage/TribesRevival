class_name TribeCommands
extends RefCounted
## Atomic semantic commands. UI never spends resources or mutates actors.

const State = preload("res://scripts/simulation/game_state.gd")
const Economy = preload("res://scripts/simulation/economy.gd")
const Rules = preload("res://scripts/simulation/survival_rules.gd")
const Move = preload("res://scripts/simulation/minion_movement.gd")
const Work = preload("res://scripts/simulation/work_system.gd")
const Idle = preload("res://scripts/simulation/minion_idle.gd")
const Progression = preload("res://scripts/simulation/progression.gd")
const Survival = preload("res://scripts/simulation/survival_system.gd")

static func apply(state: Dictionary, action: Dictionary) -> void:
	if action.type == "toggle-pause":
		if state.phase == "playing":
			state.phase = "paused"
		elif state.phase == "paused":
			state.phase = "playing"
		return
	if action.type == "debug-add-all-resources":
		for resource in Economy.RESOURCE_TYPES:
			state.inventory.amounts[resource] += 100
		return
	if action.type == "debug-level-up":
		Progression.award_experience(state.progression, maxf(0, state.progression.experienceToNextLevel - state.progression.experience))
		return
	if action.type == "debug-damage-one-minion":
		var ordered: Array = state.units.duplicate()
		ordered.sort_custom(func(a, b): return a.health < b.health if a.health != b.health else a.id < b.id)
		if not ordered.is_empty():
			Survival.damage_unit(state, ordered[0].id, 1, "barbarian")
		return
	if state.phase != "playing":
		return
	var totem: Dictionary = state.totem
	match action.type:
		"pick-up-totem":
			if not totem.isCarried:
				for unit in state.units:
					unit.erase("postCombatFree")
				totem.formationStartTick = state.tick
				totem.erase("formationStopTick")
				totem.isCarried = true
				totem.moving = false
				totem.destination = null
				totem.dragTarget = totem.position.duplicate()
		"drag-totem":
			if totem.isCarried:
				totem.position = State.clamp_position(action.position)
				totem.dragTarget = totem.position.duplicate()
		"drop-totem":
			if totem.isCarried:
				totem.formationStopTick = state.tick
				totem.isCarried = false
				totem.moving = true
				totem.destination = null
				totem.dragTarget = null
		"damage-unit":
			Survival.damage_unit(state, action.unitId, action.amount, action.sourceKind)
		"place-campfire":
			if state.campfires.size() >= 2 or state.inventory.amounts.wood < 2:
				return
			state.inventory.amounts.wood -= 2
			state.campfires.append({"id": "campfire-%02d" % state.nextCampfireId, "position": State.clamp_position(action.position), "healingRadius": 15.0, "remainingLifetimeSeconds": 120.0})
			state.nextCampfireId += 1
		"recruit-gatherer":
			var cost := Economy.recruitment_cost(state.units.size())
			if state.units.size() >= Economy.MAX_PLAYABLE_MINIONS or not Economy.spend(state.inventory.amounts, cost):
				return
			state.purchaseCounts.gatherer += 1
			var unit := State.create_unit("unit-gatherer-%02d" % (state.purchaseCounts.gatherer + 1), "gatherer", Move.project_within(action.position, totem.position, 15))
			state.units.append(unit)
			Work.set_task(unit, Rules.idle_task("action-complete") if Idle.within_range(unit.position, Move.area(state)) else Work.return_task(state, unit, "action-complete"))
		"upgrade-tool":
			if not state.toolLevels.has(action.tool) or state.toolLevels[action.tool] >= 10:
				return
			var upgrade: Variant = Economy.tool_upgrade(action.tool, state.toolLevels[action.tool] + 1)
			if upgrade != null and Economy.spend(state.inventory.amounts, upgrade.cost):
				state.toolLevels[action.tool] += 1
		"unlock-technology":
			Progression.unlock(state.progression, action.technology)
		"equip-shield":
			if "shield" not in state.progression.unlockedTechnologies:
				return
			var unit: Variant = Move.find_entity(state.units, action.unitId)
			if unit == null or unit.role != "guardian" or unit.hasShield:
				return
			var count: int = state.units.filter(func(candidate): return candidate.role == "guardian" and candidate.hasShield).size()
			if not Economy.spend(state.inventory.amounts, Economy.shield_cost(count)):
				return
			unit.hasShield = true
			unit.maxHealth += 1
			unit.health = minf(unit.health + 1, unit.maxHealth)
		"transform-unit":
			var unit: Variant = Move.find_entity(state.units, action.unitId)
			if unit == null or unit.role != "gatherer" or not Economy.SPECIALIZATIONS.has(action.item):
				return
			if action.item == "hammer" and "artisan" not in state.progression.unlockedTechnologies:
				return
			if action.item == "mage" and "mage" not in state.progression.unlockedTechnologies:
				return
			if action.item in ["axe", "hammer"] and not Rules.can_convert_last_gatherer(state.units):
				return
			var definition: Dictionary = Economy.SPECIALIZATIONS[action.item]
			var count := Rules.count_role(state.units, definition.role)
			if count >= definition.limit or not Economy.spend(state.inventory.amounts, Economy.specialization_cost(action.item, count)):
				return
			state.purchaseCounts[definition.role] += 1
			unit.role = definition.role
			Work.set_task(unit, Rules.idle_task("action-complete"))
