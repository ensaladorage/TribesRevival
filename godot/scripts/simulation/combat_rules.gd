class_name TribeCombatRules
extends RefCounted

const Economy = preload("res://scripts/simulation/economy.gd")
const MINION_MAX_HEALTH := 4
const BARBARIAN_MAX_HEALTH := 5
const BARBARIAN_ATTACK_DAMAGE := 1.0
const BARBARIAN_ATTACK_RANGE := 1.2
const BARBARIAN_ATTACK_COOLDOWN := 2.5
const BARBARIAN_DETECTION_RADIUS := 15.0
const BARBARIAN_CHASE_SPEED := 7.0
const BARBARIAN_RETURN_SPEED := 8.0
const BARBARIAN_RESPAWN_SECONDS := 60.0
const MINION_THREAT_DETECTION_RADIUS := 18.0
const ATTACKS := {
	"guardian": {"damage": 2.0, "range": 1.0, "cooldownSeconds": 1.5},
	"lumberjack": {"damage": 1.5, "range": 1.0, "cooldownSeconds": 2.0},
	"hunter": {"damage": 1.0, "range": 5.0, "cooldownSeconds": 1.3},
}
const ANIMAL_ATTACK := {"damage": 1.0, "range": 5.0, "cooldownSeconds": 1.3}

static func minion_attack(role: String, sword_level: int) -> Variant:
	if not ATTACKS.has(role):
		return null
	var attack: Dictionary = ATTACKS[role].duplicate()
	if role == "guardian":
		attack.damage += Economy.tool_effect("sword", sword_level).get("guardianDamageBonus", 0)
	return attack

static func deal_damage(source_kind: String, target_kind: String, target: Dictionary, amount: float) -> Dictionary:
	var current := maxf(target.health, 0)
	if source_kind not in ["minion", "barbarian"] or target_kind not in ["minion", "barbarian", "animal"]:
		return {"damageApplied": 0.0, "health": current, "defeated": target.health <= 0}
	var normalized := maxf(amount, 0) if is_finite(amount) else 0.0
	var health := maxf(current - normalized, 0)
	return {"damageApplied": current - health, "health": health, "defeated": health <= 0}

static func heal(target: Dictionary, amount: float) -> Dictionary:
	var normalized := maxf(amount, 0) if is_finite(amount) else 0.0
	var current := maxf(target.health, 0)
	var health := minf(current + normalized, maxf(target.maxHealth, 0))
	return {"healingApplied": health - current, "health": health}
