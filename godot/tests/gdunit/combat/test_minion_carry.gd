extends GdUnitTestSuite

const Session = preload("res://scripts/simulation/game_session.gd")
const Carry = preload("res://scripts/simulation/minion_carry.gd")
const Saves = preload("res://scripts/persistence/save_repository.gd")
const ROLES := ["gatherer", "lumberjack", "hunter", "guardian", "artisan", "mage", "explorer"]

func _session(role: String = "guardian") -> RefCounted:
	var session := Session.new("carry-regression")
	session.state.terrain = preload("res://tests/support/flat_terrain.gd").rows()
	session.state.units = [Session.State.create_unit("rescued", role, {"x": 85.0, "y": 80.0})]
	session.state.resources = []
	session.state.barbarians = []
	session.state.animals = []
	session.state.weather.nextCloudInSeconds = 10000.0
	return session

func _enemy(state: Dictionary, point: Dictionary) -> Dictionary:
	var enemy: Dictionary = Session.State.Catalog.create_barbarians(state.seed)[0]
	enemy.position = point.duplicate()
	enemy.spawnPosition = {"x": 120.0, "y": 120.0}
	enemy.targetUnitId = "rescued"
	state.barbarians.append(enemy)
	return enemy

func _action(session: RefCounted, kind: String, point: Variant = null, id: String = "rescued") -> void:
	var action := {"type": kind, "unitId": id}
	if point != null:
		action.position = point
	session.enqueue(action)
	session.flush_actions()

func test_all_roles_are_safe_and_frozen_while_carried() -> void:
	for role in ROLES:
		var session := _session(role)
		var unit: Dictionary = session.state.units[0]
		unit.health = 2.0
		unit.attackCooldownRemainingSeconds = 1.3
		unit.attackLockRemainingSeconds = 0.12
		unit.healingProgressSeconds = 7.9
		session.state.inventory.amounts.food = 10
		session.state.campfires = [{"id": "fire", "position": unit.position.duplicate(), "healingRadius": 15.0, "remainingLifetimeSeconds": 120.0}]
		_action(session, "pick-up-minion")
		var inventory: Dictionary = session.state.inventory.duplicate(true)
		for tick in 200:
			session.advance(Session.FIXED_DT)
		Session.Survival.damage_unit(session.state, unit.id, 99, "barbarian")
		assert_int(session.state.units.size()).is_equal(1)
		assert_float(float(unit.health)).is_equal(2.0)
		assert_float(float(unit.attackCooldownRemainingSeconds)).is_equal(1.3)
		assert_float(float(unit.attackLockRemainingSeconds)).is_equal(0.12)
		assert_float(float(unit.healingProgressSeconds)).is_equal(7.9)
		assert_float(float(unit.actionProgressSeconds)).is_equal(0.0)
		assert_bool(session.state.inventory == inventory).is_true()
		assert_str(unit.state).is_equal("carried")

func test_only_one_unit_or_totem_can_be_carried() -> void:
	var session := _session()
	session.state.units.append(Session.State.create_unit("other", "gatherer", {"x": 88, "y": 80}))
	_action(session, "pick-up-minion", null, "missing")
	assert_bool(Carry.held_unit(session.state) == null).is_true()
	_action(session, "pick-up-minion")
	_action(session, "pick-up-minion", null, "other")
	_action(session, "pick-up-totem")
	assert_str(Carry.held_unit(session.state).id).is_equal("rescued")
	assert_bool(session.state.totem.isCarried).is_false()
	_action(session, "drop-minion")
	_action(session, "pick-up-totem")
	_action(session, "pick-up-minion")
	assert_bool(Carry.held_unit(session.state) == null).is_true()
	assert_bool(session.state.totem.isCarried).is_true()

func test_enemy_immediately_switches_to_valid_attacker_then_returns_without_targets() -> void:
	var session := _session()
	var ally := Session.State.create_unit("ally", "guardian", {"x": 88.0, "y": 80.0})
	session.state.units.append(ally)
	var enemy := _enemy(session.state, {"x": 86.0, "y": 80.0})
	Session.Work.set_task(ally, {"kind": "combat", "targetResourceId": null, "targetEntityId": enemy.id, "destination": null, "cause": "threat-nearby"})
	_action(session, "pick-up-minion")
	assert_str(enemy.targetUnitId).is_equal(ally.id)
	session.state.units.erase(ally)
	Session.Conflict.retarget_enemies(session.state)
	assert_bool(enemy.targetUnitId == null).is_true()
	assert_bool(enemy.returningToSpawn).is_true()
	var before: Dictionary = enemy.position.duplicate()
	session.advance(Session.FIXED_DT)
	assert_bool(enemy.position != before).is_true()
	assert_str(session.state.phase).is_equal("playing")

func test_carried_minion_does_not_detect_call_or_block() -> void:
	var session := _session("mage")
	var ally := Session.State.create_unit("ally", "guardian", {"x": 85.0, "y": 80.0})
	session.state.units.append(ally)
	_action(session, "pick-up-minion")
	_action(session, "drag-minion", {"x": 115.0, "y": 80.0})
	var enemy := _enemy(session.state, {"x": 115.0, "y": 81.0})
	session.advance(Session.FIXED_DT)
	assert_bool(enemy.targetUnitId == null).is_true()
	assert_str(ally.task.kind).is_equal("idle")
	assert_int(session.state.alerts.size()).is_equal(0)
	var frame := Session.Movement.create_frame(session.state, Session.FIXED_DT)
	var neighbors := Session.Movement.neighbors(session.state, ally, frame)
	assert_bool(neighbors.any(func(other): return other.id == "rescued")).is_false()
	var position: Dictionary = session.state.units[0].position.duplicate()
	Session.Movement.resolve_spacing(session.state)
	assert_bool(session.state.units[0].position == position).is_true()

func test_drop_outside_command_returns_all_roles_without_starting_attacks() -> void:
	for role in ROLES:
		var session := _session(role)
		var unit: Dictionary = session.state.units[0]
		_action(session, "pick-up-minion")
		_action(session, "drag-minion", {"x": 125.0, "y": 80.0})
		var enemy := _enemy(session.state, {"x": 127.0, "y": 80.0})
		_action(session, "drop-minion")
		assert_str(unit.task.kind).is_equal("return-to-totem")
		session.advance(Session.FIXED_DT)
		assert_bool(unit.position.x < 125.0 and unit.position.x > 120.0).is_true()
		assert_float(float(enemy.health)).is_equal(float(enemy.maxHealth))
		assert_bool(not unit.get("isCarried", false)).is_true()

func test_repeated_pickups_do_not_reset_cooldown_or_grant_hits() -> void:
	var session := _session()
	var unit: Dictionary = session.state.units[0]
	unit.attackCooldownRemainingSeconds = 1.0
	var enemy := _enemy(session.state, {"x": 86.0, "y": 80.0})
	for attempt in 20:
		_action(session, "pick-up-minion")
		for tick in 4:
			session.advance(Session.FIXED_DT)
		_action(session, "drop-minion")
	assert_float(float(unit.attackCooldownRemainingSeconds)).is_equal(1.0)
	assert_float(float(enemy.health)).is_equal(float(enemy.maxHealth))
	Session.Survival.damage_unit(session.state, unit.id, 1, "barbarian")
	assert_float(float(unit.health)).is_equal(3.0)
	enemy.position = {"x": 86.0, "y": 80.0}
	session.advance(Session.FIXED_DT)
	assert_str(unit.task.kind).is_equal("combat")
	assert_float(float(unit.attackCooldownRemainingSeconds)).is_equal_approx(0.95, 0.00001)

func test_combat_pickup_lock_survives_pause_save_and_reentry() -> void:
	var session := _session("hunter")
	var unit: Dictionary = session.state.units[0]
	var enemy := _enemy(session.state, {"x": 86.0, "y": 80.0})
	var combat := {"kind": "combat", "cause": "threat-nearby", "targetResourceId": null, "targetEntityId": enemy.id, "destination": null}
	Session.Work.set_task(unit, combat)
	unit.attackCooldownRemainingSeconds = 1.0
	var terrain = Session.Movement.Terrain
	var plateau: Dictionary = terrain.center(Vector2i(72, 78))
	var row: String = session.state.terrain[78]
	session.state.terrain[78] = row.left(72) + "2" + row.substr(73)
	assert_bool(terrain.same_level(session.state.terrain, unit.position, plateau)).is_false()
	var before: Dictionary = session.state.duplicate(true)
	_action(session, "pick-up-minion")
	_action(session, "drag-minion", plateau)
	assert_bool(session.state == before).is_true()

	session.state.barbarians.clear()
	session.advance(Session.FIXED_DT)
	assert_int(int(unit.pickupLockTicks)).is_equal(40)
	for step in 20:
		session.advance(Session.FIXED_DT)
	_action(session, "toggle-pause")
	session.advance(0.20)
	assert_int(int(unit.pickupLockTicks)).is_equal(20)
	var directory := "user://combat-pickup-tests-%s" % Time.get_ticks_usec()
	var saves := Saves.new(directory)
	assert_bool(saves.save_slot(1, session.state).ok).is_true()
	var loaded := saves.read_slot(1)
	assert_str(loaded.status).is_equal("valid")
	session.replace_state(loaded.save.gameState)
	unit = session.state.units[0]
	saves.delete_slot(1)
	DirAccess.remove_absolute(directory)

	for step in 19:
		session.advance(Session.FIXED_DT)
	_action(session, "pick-up-minion")
	assert_bool(unit.get("isCarried", false)).is_false()
	session.advance(Session.FIXED_DT)
	assert_bool(Carry.can_pick_up(session.state, unit)).is_true()

	Session.Work.set_task(unit, combat)
	Session.Work.set_task(unit, Session.Work.return_task(session.state, unit, "totem-moved"))
	for step in 20:
		session.advance(Session.FIXED_DT)
	Session.Work.set_task(unit, combat)
	var totem_position: Dictionary = session.state.totem.position
	session.state.totem.position = {"x": 40.0, "y": 80.0}
	session.state.totem.moving = true
	session.advance(Session.FIXED_DT)
	assert_str(unit.task.kind).is_not_equal("combat")
	assert_int(int(unit.pickupLockTicks)).is_equal(40)
	session.state.totem.position = totem_position
	session.state.totem.moving = false
	for step in 39:
		session.advance(Session.FIXED_DT)
	_action(session, "pick-up-minion")
	assert_bool(unit.get("isCarried", false)).is_false()
	session.advance(Session.FIXED_DT)
	_action(session, "pick-up-minion")
	assert_bool(unit.get("isCarried", false)).is_true()

func test_all_roles_reject_pickup_and_drag_in_combat() -> void:
	for role in Session.Work.Rules.AFFINITY:
		var session := _session(role)
		var unit: Dictionary = session.state.units[0]
		var position: Dictionary = unit.position.duplicate()
		Session.Work.set_task(unit, {"kind": "combat", "targetResourceId": null})
		_action(session, "pick-up-minion")
		_action(session, "drag-minion", {"x": 100, "y": 100})
		assert_bool(unit.get("isCarried", false)).is_false()
		assert_bool(unit.position == position).is_true()

func test_ranged_fighters_remain_locked_through_a_long_pursuit() -> void:
	for role in ["hunter", "mage"]:
		var session := _session(role)
		var unit: Dictionary = session.state.units[0]
		unit.health = 100
		var enemy := _enemy(session.state, {"x": 86.0, "y": 80.0})
		enemy.health = 100
		for tick in 80:
			session.advance(Session.FIXED_DT)
			assert_str(unit.task.kind).is_equal("flee")
			var position: Dictionary = unit.position.duplicate()
			_action(session, "pick-up-minion")
			_action(session, "drag-minion", {"x": 100, "y": 100})
			assert_bool(unit.get("isCarried", false)).is_false()
			assert_bool(unit.position == position).is_true()
		session.state.barbarians.clear()
		session.advance(Session.FIXED_DT)
		assert_int(int(unit.get("pickupLockTicks", 0))).is_equal(40)
		for tick in 40:
			session.advance(Session.FIXED_DT)
		assert_bool(Carry.can_pick_up(session.state, unit)).is_true()

func test_fleeing_without_prior_combat_can_be_picked_up() -> void:
	var session := _session("gatherer")
	var unit: Dictionary = session.state.units[0]
	var enemy := _enemy(session.state, {"x": 86.0, "y": 80.0})
	Session.Work.set_task(unit, {"kind": "flee", "cause": "pursued", "targetResourceId": null, "targetEntityId": enemy.id, "destination": unit.position.duplicate()})
	_action(session, "pick-up-minion")
	assert_bool(unit.get("isCarried", false)).is_true()

func test_returning_civilian_does_not_stop_to_avoid_someone_elses_fight() -> void:
	var session := _session("gatherer")
	var unit: Dictionary = session.state.units[0]
	var ally := Session.State.create_unit("ally", "guardian", {"x": 126.0, "y": 82.0})
	session.state.units.append(ally)
	_action(session, "pick-up-minion")
	_action(session, "drag-minion", {"x": 125.0, "y": 80.0})
	var enemy := _enemy(session.state, {"x": 126.0, "y": 80.0})
	enemy.targetUnitId = ally.id
	_action(session, "drop-minion")
	session.advance(Session.FIXED_DT)
	assert_str(unit.task.kind).is_equal("return-to-totem")
	assert_bool(unit.position.x < 125.0).is_true()

func test_pickup_releases_work_and_discards_partial_progress() -> void:
	var session := _session("gatherer")
	var unit: Dictionary = session.state.units[0]
	Session.Work.set_task(unit, {"kind": "gather", "targetResourceId": "resource", "destination": null, "cause": "resource-found"})
	unit.actionProgressSeconds = 0.9
	_action(session, "pick-up-minion")
	var ally := Session.State.create_unit("ally", "gatherer", {"x": 88, "y": 80})
	assert_int(Session.Work.reserved_targets(session.state, ally, "gather").size()).is_equal(0)
	assert_float(float(unit.actionProgressSeconds)).is_equal(0.0)
	assert_int(session.state.drops.size()).is_equal(0)
	assert_float(float(session.state.progression.experience)).is_equal(0.0)

func test_off_center_drop_stays_beside_blocker_at_fractional_positions() -> void:
	var session := _session()
	var state: Dictionary = session.state
	var unit: Dictionary = state.units[0]
	var ally := Session.State.create_unit("blocker", "guardian", {"x": 137.37, "y": 145.81})
	state.units.append(ally)
	state.totem.position = {"x": 112.31, "y": 125.87}
	for blocker in [ally, state.totem]:
		var radius: float = Carry.Move.TOTEM_CLEARANCE if blocker == state.totem else Carry.Move.Nav.MINIMUM_SEPARATION
		for index in 36:
			var angle := TAU * index / 36.0
			var requested := {"x": blocker.position.x + 0.3 * cos(angle), "y": blocker.position.y + 0.3 * sin(angle)}
			var landed := Carry.drop_position(state, unit, requested)
			assert_float(Carry.Move.Geo.distance(requested, landed)).is_equal_approx(radius - 0.3, 0.0001)
			assert_float(Carry.Move.Geo.distance(blocker.position, landed)).is_equal_approx(radius, 0.0001)

func test_nearest_free_drop_respects_bodies_totem_edges_and_determinism() -> void:
	var session := _session()
	var unit: Dictionary = session.state.units[0]
	var ally := Session.State.create_unit("ally", "gatherer", {"x": 85.0, "y": 80.0})
	session.state.units.append(ally)
	var before: Dictionary = ally.position.duplicate()
	_action(session, "pick-up-minion")
	var first := Carry.drop_position(session.state, unit, ally.position)
	assert_float(Session.Movement.Geo.distance(first, ally.position)).is_equal_approx(Session.Movement.Nav.MINIMUM_SEPARATION, 0.00001)
	assert_bool(ally.position == before).is_true()
	for requested in [{"x": 80.0, "y": 80.0}, {"x": -100.0, "y": 400.0}, ally.position]:
		var point := Carry.drop_position(session.state, unit, requested)
		assert_bool(point.x >= 2 and point.x <= 158 and point.y >= 2 and point.y <= 158).is_true()
		assert_bool(Session.Movement.Geo.distance(point, session.state.totem.position) >= Session.Movement.TOTEM_CLEARANCE - 0.00001).is_true()
		assert_bool(point == Carry.drop_position(session.state, unit, requested)).is_true()
	session.state.totem.position = {"x": 2.0, "y": 2.0}
	var edge := Carry.drop_position(session.state, unit, {"x": 2, "y": 2})
	assert_bool(edge.x >= 2 and edge.y >= 2).is_true()
	assert_float(Session.Movement.Geo.distance(edge, session.state.totem.position)).is_equal_approx(Session.Movement.TOTEM_CLEARANCE, 0.00001)

func test_pause_and_saved_state_deposit_without_mutating_source_or_breaking_old_saves() -> void:
	var session := _session()
	var directory := "user://carry-tests-%s" % Time.get_ticks_usec()
	var saves := Saves.new(directory)
	var old := saves.save_slot(1, session.state)
	assert_bool(old.ok).is_true()
	assert_str(saves.read_slot(1).status).is_equal("valid")
	_action(session, "pick-up-minion")
	_action(session, "drag-minion", {"x": 120, "y": 100})
	var saved := saves.save_slot(2, session.state)
	assert_bool(saved.ok).is_true()
	assert_bool(Carry.held_unit(session.state) != null).is_true()
	var loaded := saves.read_slot(2)
	assert_str(loaded.status).is_equal("valid")
	assert_bool(Carry.held_unit(loaded.save.gameState) == null).is_true()
	assert_str(loaded.save.gameState.units[0].task.kind).is_equal("return-to-totem")
	_action(session, "toggle-pause")
	assert_bool(Carry.held_unit(session.state) == null).is_true()
	assert_str(session.state.phase).is_equal("paused")
	# JSON normalizes integer counters to floats and StringName keys to strings.
	var expected: Dictionary = JSON.parse_string(JSON.stringify(Saves.normalized_state(session.state), "", false, true))
	assert_bool(expected.units == loaded.save.gameState.units).is_true()
	saves.delete_slot(1)
	saves.delete_slot(2)
	DirAccess.remove_absolute(directory)

func test_same_actions_produce_identical_state() -> void:
	var first := _session("hunter")
	var second := _session("hunter")
	for session in [first, second]:
		_action(session, "pick-up-minion")
		_action(session, "drag-minion", {"x": 130, "y": 110})
		for tick in 25:
			session.advance(Session.FIXED_DT)
		_action(session, "drop-minion")
		for tick in 80:
			session.advance(Session.FIXED_DT)
	assert_str(Saves.fingerprint(first.state)).is_equal(Saves.fingerprint(second.state))

func test_carried_minion_cannot_call_allies_to_distant_resources() -> void:
	var session := _session("guardian")
	var caller: Dictionary = session.state.units[0]
	var ally := Session.State.create_unit("lumberjack", "lumberjack", {"x": 84.0, "y": 80.0})
	session.state.units.append(ally)
	session.state.resources = [{"id": "distant-tree", "type": "wood", "source": "tree", "position": {"x": 121.0, "y": 80.0}, "amount": 10, "interactionRadius": 1.2}]
	_action(session, "pick-up-minion")
	_action(session, "drag-minion", {"x": 120.0, "y": 80.0})
	assert_bool(Session.Work.dispatch_resource_call(session.state, caller)).is_false()
	for tick in 80:
		session.advance(Session.FIXED_DT)
	assert_bool(ally.task.get("targetResourceId") == null).is_true()
	assert_bool(Session.Movement.Idle.within_range(ally.position, Session.Movement.area(session.state))).is_true()
	# Dropping the caller far away must not send the ally outside the work area.
	_action(session, "drop-minion")
	assert_bool(Session.Work.dispatch_resource_call(session.state, caller)).is_false()
	for tick in 80:
		session.advance(Session.FIXED_DT)
	assert_bool(ally.task.get("targetResourceId") == null).is_true()
	assert_bool(Session.Movement.Idle.within_range(ally.position, Session.Movement.area(session.state))).is_true()
	# Grounded callers still communicate resources inside the totem's work area.
	caller.position = {"x": 89.0, "y": 80.0}
	session.state.resources[0].position = {"x": 90.0, "y": 80.0}
	assert_bool(Session.Work.dispatch_resource_call(session.state, caller)).is_true()
	assert_str(ally.task.cause).is_equal("resource-call-received")

func test_resource_calls_respect_totem_radius_and_five_percent_margin() -> void:
	for radius in [10.0, 16.0]:
		for offset in [-0.01, 0.0, 0.01]:
			var session := _session("guardian")
			session.state.totem.commandRadius = radius
			var caller: Dictionary = session.state.units[0]
			caller.position = {"x": 80.0 + radius, "y": 80.0}
			var ally := Session.State.create_unit("lumberjack", "lumberjack", {"x": 84.0, "y": 80.0})
			session.state.units.append(ally)
			session.state.resources = [{"id": "boundary-tree", "type": "wood", "source": "tree", "position": {"x": 80.0 + radius * 1.05 + offset, "y": 80.0}, "amount": 10, "interactionRadius": 1.2}]
			var accepted := Session.Work.dispatch_resource_call(session.state, caller)
			assert_bool(accepted).is_equal(offset <= 0.0)
			assert_bool(ally.task.get("targetResourceId") == "boundary-tree").is_equal(offset <= 0.0)

func test_sacrifice_is_atomic_and_persists() -> void:
	var session := _session()
	session.state.units.append(Session.State.create_unit("other", "guardian", {"x": 90, "y": 80}))
	var food := int(session.state.inventory.amounts.food)
	_action(session, "pick-up-minion")
	_action(session, "sacrifice-minion", null, "other")
	assert_int(session.state.units.size()).is_equal(2)
	_action(session, "sacrifice-minion")
	_action(session, "sacrifice-minion")
	var directory := "user://sacrifice-tests-%s" % Time.get_ticks_usec()
	var saves := Saves.new(directory)
	assert_bool(saves.save_slot(1, session.state).ok).is_true()
	var loaded: Dictionary = saves.read_slot(1).save.gameState
	assert_int(loaded.units.size()).is_equal(1)
	assert_str(loaded.units[0].id).is_equal("other")
	assert_int(int(loaded.inventory.amounts.food)).is_equal(food + 1)
	assert_int(loaded.corpses.size()).is_equal(0)
	saves.delete_slot(1)
	DirAccess.remove_absolute(directory)

func test_sacrifice_protects_the_only_food_producer() -> void:
	for role in ["gatherer", "hunter"]:
		var session := _session(role)
		session.state.units.append(Session.State.create_unit("guard", "guardian", {"x": 90, "y": 80}))
		var food := int(session.state.inventory.amounts.food)
		_action(session, "pick-up-minion")
		_action(session, "drag-minion", {"x": 140, "y": 80})
		_action(session, "sacrifice-minion")
		var landed: Dictionary = session.state.units[0].position
		# The guard occupies the nearest boundary point. Land beside it on the same edge.
		assert_float(Session.Movement.Geo.distance(landed, session.state.totem.position)).is_equal_approx(10.0, 0.001)
		assert_float(Session.Movement.Geo.distance(landed, session.state.units[1].position)).is_equal_approx(Session.Movement.Nav.MINIMUM_SEPARATION, 0.001)
		assert_int(session.state.units.size()).is_equal(2)
		assert_int(int(session.state.inventory.amounts.food)).is_equal(food)
		assert_bool(Carry.held_unit(session.state) == null).is_true()

func test_rejected_sacrifice_starts_interpolation_at_landing_point() -> void:
	var session := _session("gatherer")
	_action(session, "pick-up-minion")
	_action(session, "drag-minion", {"x": 140.0, "y": 80.0})
	session.enqueue({"type": "sacrifice-minion", "unitId": "rescued"})
	session.advance(Session.FIXED_DT)
	var origin: Dictionary = session.previous_positions["rescued"]
	assert_float(float(origin.x)).is_equal_approx(90.0, 0.001)
	assert_float(float(origin.y)).is_equal_approx(80.0, 0.001)
	assert_bool(Carry.held_unit(session.state) == null).is_true()
