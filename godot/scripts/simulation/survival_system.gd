class_name TribeSurvivalSystem
extends RefCounted

const Combat = preload("res://scripts/simulation/combat_rules.gd")
const Geo = preload("res://scripts/simulation/geometry.gd")

static func add_effect(state: Dictionary, kind: String, target_id: String, point: Dictionary, duration: float) -> void:
	state.effects.append({"id": "effect-%04d" % state.nextEffectId, "kind": kind, "targetId": target_id, "position": point.duplicate(), "ageSeconds": 0.0, "durationSeconds": duration})
	state.nextEffectId += 1

static func age_effects(state: Dictionary, delta: float) -> void:
	for effect in state.effects:
		effect.ageSeconds += delta
	state.effects = state.effects.filter(func(effect): return effect.ageSeconds < effect.durationSeconds)
	for alert in state.alerts:
		alert.ageSeconds += delta
	state.alerts = state.alerts.filter(func(alert): return alert.ageSeconds < alert.durationSeconds)

static func update_cooldowns(state: Dictionary, delta: float) -> void:
	for unit in state.units:
		unit.attackCooldownRemainingSeconds = maxf(unit.attackCooldownRemainingSeconds - delta, 0)
		unit.attackLockRemainingSeconds = maxf(unit.attackLockRemainingSeconds - delta, 0)

static func damage_unit(state: Dictionary, id: String, amount: float, source_kind: String) -> float:
	var unit: Variant = null
	for candidate in state.units:
		if candidate.id == id:
			unit = candidate
			break
	if unit == null:
		return 0.0
	var result := Combat.deal_damage(source_kind, "minion", unit, amount)
	unit.health = result.health
	if result.damageApplied > 0:
		add_effect(state, "damage-flash", unit.id, unit.position, 0.3)
	if result.defeated:
		state.corpses.append({"id": "corpse-%03d" % (state.corpses.size() + 1), "formerUnitId": unit.id, "position": unit.position.duplicate()})
		state.units.remove_at(state.units.find(unit))
		if state.units.is_empty():
			state.phase = "defeat"
	return result.damageApplied

static func record_alert(state: Dictionary, detector_kind: String, id: String, point: Dictionary, play_sound: bool) -> void:
	state.alerts.append({"id": "alert-%05d" % state.nextAlertId, "detectorKind": detector_kind, "detectorId": id, "position": point.duplicate(), "ageSeconds": 0.0, "durationSeconds": 1.4, "playSound": play_sound})
	state.nextAlertId += 1

static func update_campfires(state: Dictionary, delta: float) -> void:
	for campfire in state.campfires:
		campfire.remainingLifetimeSeconds = maxf(campfire.remainingLifetimeSeconds - delta, 0)
	state.campfires = state.campfires.filter(func(campfire):
		var dx: float = campfire.position.x - state.totem.position.x
		var dy: float = campfire.position.y - state.totem.position.y
		return campfire.remainingLifetimeSeconds > 0 and dx * dx + dy * dy <= 900.0)
	for unit in state.units:
		var matching: Array = state.campfires.filter(func(campfire): return Geo.distance(unit.position, campfire.position) <= campfire.get("healingRadius", 15.0))
		matching.sort_custom(func(a, b): return a.id < b.id)
		if matching.is_empty() or unit.health >= unit.maxHealth or state.inventory.amounts.food < 1:
			unit.healingProgressSeconds = 0.0
			continue
		unit.healingProgressSeconds += delta
		if unit.healingProgressSeconds + 1e-9 < 8.0:
			continue
		unit.healingProgressSeconds -= 8.0
		var result := Combat.heal(unit, 1)
		if result.healingApplied > 0:
			unit.health = result.health
			state.inventory.amounts.food -= 1
			add_effect(state, "heal-crosses", unit.id, unit.position, 0.9)
