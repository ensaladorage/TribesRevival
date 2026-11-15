extends SceneTree
const Session = preload("res://scripts/simulation/game_session.gd")
const State = preload("res://scripts/simulation/game_state.gd")
const Work = preload("res://scripts/simulation/work_system.gd")
const Combat = preload("res://scripts/simulation/combat_rules.gd")
const Conflict = preload("res://scripts/simulation/conflict_system.gd")
const Movement = preload("res://scripts/simulation/minion_movement.gd")
const Survival = preload("res://scripts/simulation/survival_system.gd")
const Geo = preload("res://scripts/simulation/geometry.gd")
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _initialize() -> void:
	var stats: Dictionary = Combat.minion_attack("mage", 10)
	check(stats.damage == 2.0 and stats.range == 3.0 and stats.cooldownSeconds == 2.5, "Mage approved stats, unaffected by sword")
	check(Combat.is_ranged("mage", 0) and not Combat.is_melee("mage", 0), "Mage is ranged")
	var session := Session.new("mage-basic")
	var state: Dictionary = session.state
	state.resources = []
	state.animals = []
	state.weather.clouds = []
	var mage := State.create_unit("mage-test", "mage", {"x": 87.6, "y": 80.0})
	var tank := State.create_unit("tank", "guardian", {"x": 84.02, "y": 80.0})
	tank.health = 1000.0
	tank.maxHealth = 1000.0
	var enemy: Dictionary = state.barbarians[0]
	enemy.position = {"x": 85.0, "y": 80.0}
	enemy.spawnPosition = enemy.position.duplicate()
	enemy.health = 1000.0
	enemy.maxHealth = 1000.0
	enemy.targetUnitId = tank.id
	state.barbarians = [enemy]
	state.units = [mage, tank]
	var last_shot := -1000
	var shots := 0
	var seen := {}
	for tick in 200:
		session.advance(0.05)
		for effect in state.effects:
			if effect.kind == "attack-lunge" and effect.targetId == mage.id and not seen.has(effect.id):
				seen[effect.id] = true
				check(tick - last_shot >= 50, "Mage cannot shoot faster than 2.5 seconds")
				check(Geo.distance(mage.position, enemy.position) <= 3.001, "Mage fires inside three metres")
				check(Geo.distance(mage.position, enemy.position) >= 2.39, "Mage maintains ranged position")
				last_shot = tick
				shots += 1
		check(Geo.distance(mage.position, state.totem.position) <= 10.00001, "Mage stays in command radius")
	check(shots >= 3, "Mage repeatedly fights alongside melee")
	var before: float = enemy.health
	Conflict._attack(state, mage, enemy, stats, "barbarian")
	check(enemy.health == before - 2.0, "Mage deals two damage")
	Survival.update_cooldowns(state, 0.5)
	var remaining: float = mage.attackCooldownRemainingSeconds
	Work.set_task(mage, {"kind": "combat", "targetEntityId": "other-enemy", "targetResourceId": null, "destination": null, "cause": "threat-nearby"})
	check(remaining == 2.0 and mage.attackCooldownRemainingSeconds == remaining, "Cooldown survives target change")
	# Without enemies the mage must not acquire animals for hunting.
	state.barbarians = []
	state.animals = State.create_initial("mage-no-hunt").animals
	state.animals[0].position = mage.position.duplicate()
	mage.attackLockRemainingSeconds = 0.0
	Conflict.update(state, 0.05, Movement.create_frame(state, 0.05))
	check(mage.task.kind != "hunt", "Mage does not hunt sheep")
	for failure in failures: push_error(failure)
	print("%s mage basic combat: %d shots, range, damage, cooldown, command radius and no hunting" % ["PASS" if failures.is_empty() else "FAIL", shots])
	quit(0 if failures.is_empty() else 1)
