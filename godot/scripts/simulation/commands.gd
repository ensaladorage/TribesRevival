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
const Carry = preload("res://scripts/simulation/minion_carry.gd")
const Conflict = preload("res://scripts/simulation/conflict_system.gd")
const Survival = preload("res://scripts/simulation/survival_system.gd")

static func unit_item_cost(state: Dictionary, item: String, unit: Variant) -> Variant:
	if unit == null:
		return null
	if item == "shield":
		if "shield" not in state.progression.unlockedTechnologies or unit.role != "guardian" or unit.hasShield:
			return null
		var shielded: int = state.units.filter(func(candidate): return candidate.role == "guardian" and candidate.hasShield).size()
		return Economy.shield_cost(shielded)
	if unit.role != "gatherer" or not Economy.SPECIALIZATIONS.has(item):
		return null
	if item == "hammer" and "artisan" not in state.progression.unlockedTechnologies:
		return null
	if item == "mage" and "mage" not in state.progression.unlockedTechnologies:
		return null
	if item in ["axe", "hammer"] and not Rules.can_convert_last_gatherer(state.units):
		return null
	var definition: Dictionary = Economy.SPECIALIZATIONS[item]
	var count := Rules.count_role(state.units, definition.role)
	return Economy.specialization_cost(item, count) if count < definition.limit else null

static func apply(state: Dictionary, action: Dictionary) -> void:
	if action.type == "toggle-pause":
		Carry.drop_all(state)
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
		"pick-up-minion":
			if Carry.pick_up(state, action.unitId):
				Conflict.retarget_enemies(state)
		"drag-minion":
			Carry.drag(state, action.unitId, action.position, action.get("surfaceValid",true))
		"sacrifice-minion":
			var unit: Variant = Carry.held_unit(state)
			if unit != null and unit.id == action.unitId:
				if Rules.sacrifice_block_reason(state.units, unit.id).is_empty():
					state.units.erase(unit)
					state.inventory.amounts.food += 1
				else:
					Carry.drop(state, unit.id, true)
		"drop-minion":
			Carry.drop(state, action.unitId)
		"pick-up-totem":
			if not totem.isCarried and Carry.held_unit(state) == null:
				for unit in state.units:
					unit.erase("postCombatFree")
					unit.erase("formationSlot")
					unit.erase("formationActivityCenter")
				totem.formationStartTick = state.tick
				totem.erase("formationStopTick")
				totem.lastLanding = totem.position.duplicate()
				totem.isCarried = true
				totem.moving = false
				totem.destination = null
				totem.dragTarget = totem.position.duplicate()
		"drag-totem":
			if totem.isCarried:
				totem.position = State.clamp_position(action.position)
				if action.get("surfaceValid",true) and Move.Terrain.fits(state.get("terrain",[]),totem.position,1.0,true):
					totem.lastLanding = totem.position.duplicate()
				totem.dragTarget = totem.position.duplicate()
		"drop-totem":
			if totem.isCarried:
				totem.position = totem.get("lastLanding",totem.position)
				totem.erase("lastLanding")
				totem.formationStopTick = state.tick
				totem.isCarried = false
				totem.moving = true
				totem.destination = null
				totem.dragTarget = null
		"damage-unit":
			Survival.damage_unit(state, action.unitId, action.amount, action.sourceKind)
		"place-campfire":
			if not Move.Terrain.fits(state.get("terrain",[]),action.position,0.9,true):
				return
			if state.campfires.size() >= 2 or state.inventory.amounts.wood < 2:
				return
			state.inventory.amounts.wood -= 2
			state.campfires.append({"id": "campfire-%02d" % state.nextCampfireId, "position": State.clamp_position(action.position), "healingRadius": 15.0, "remainingLifetimeSeconds": 120.0})
			state.nextCampfireId += 1
		"recruit-gatherer":
			var spawn := Move.project_within(action.position,totem.position,15)
			if not Move.Terrain.fits(state.get("terrain",[]),action.position,0.32,true) or not Move.Terrain.fits(state.get("terrain",[]),spawn,0.32,true):
				return
			var cost := Economy.recruitment_cost(state.units.size())
			if state.units.size() >= Economy.MAX_PLAYABLE_MINIONS or not Economy.spend(state.inventory.amounts, cost):
				return
			state.purchaseCounts.gatherer += 1
			var unit := State.create_unit("unit-gatherer-%02d" % (state.purchaseCounts.gatherer + 1), "gatherer", spawn)
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
			var unit: Variant = Move.find_entity(state.units, action.unitId)
			var cost: Variant = unit_item_cost(state, "shield", unit)
			if cost == null or not Economy.spend(state.inventory.amounts, cost):
				return
			unit.hasShield = true
			unit.maxHealth += 1
			unit.health = minf(unit.health + 1, unit.maxHealth)
		"transform-unit":
			var unit: Variant = Move.find_entity(state.units, action.unitId)
			var cost: Variant = unit_item_cost(state, action.item, unit)
			if action.item == "shield" or cost == null or not Economy.spend(state.inventory.amounts, cost):
				return
			var definition: Dictionary = Economy.SPECIALIZATIONS[action.item]
			state.purchaseCounts[definition.role] += 1
			unit.role = definition.role
			Work.set_task(unit, Rules.idle_task("action-complete"))
