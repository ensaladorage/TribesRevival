extends SceneTree
## Cross-language data parity. No scene rendering, simulation steps, or input.

const Random = preload("res://scripts/simulation/seeded_random.gd")
const State = preload("res://scripts/simulation/game_state.gd")
const Economy = preload("res://scripts/simulation/economy.gd")
const Progression = preload("res://scripts/simulation/progression.gd")
const Navigation = preload("res://scripts/simulation/navigation.gd")
const Idle = preload("res://scripts/simulation/minion_idle.gd")
const CombatPositions = preload("res://scripts/simulation/combat_positions.gd")
const Awareness = preload("res://scripts/simulation/minion_awareness.gd")
const Rules = preload("res://scripts/simulation/survival_rules.gd")
const Movement = preload("res://scripts/simulation/minion_movement.gd")
const Combat = preload("res://scripts/simulation/combat_rules.gd")
const Commands = preload("res://scripts/simulation/commands.gd")
const Saves = preload("res://scripts/persistence/save_repository.gd")
const Work = preload("res://scripts/simulation/work_system.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	var reference: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/typescript_reference.json"))
	if not reference is Dictionary:
		push_error("Invalid TypeScript reference fixture")
		quit(1)
		return
	for sample in reference.random:
		var random := Random.new(sample.seed)
		for expected in sample.uints:
			_equal(random.next_uint(), expected, "PRNG: " + sample.seed)
	for expected in reference.initialStates:
		var actual := State.create_initial(expected.seed)
		_equal(actual, expected, "initial: " + expected.seed)
	_test_economy(reference.economy)
	_test_transactions()
	_test_support(reference.support)
	_test_blocked_idle_yield()
	_test_purchases(reference.purchases)
	_test_current_save()
	for sample in reference.durations:
		_equal(Work.gather_duration({"toolLevels": sample.levels}, sample.node), sample.result, "gather duration")
	for sample in reference.combat.attacks:
		_equal(Combat.minion_attack(sample.role, sample.level), sample.result, "attack statistics")
	for sample in reference.combat.damage:
		_equal(Combat.deal_damage(sample.source, sample.target, {"health": 4, "maxHealth": 4}, sample.amount), sample.result, "damage rule")
	for sample in reference.combat.heal:
		_equal(Combat.heal({"health": 2, "maxHealth": 4}, sample.amount), sample.result, "healing rule")
	if failures.is_empty():
		print("PASS data: %d comparisons (TypeScript parity, pure invariants, current saves); 4 worlds; no gameplay ticks" % checks)
		quit(0)
	else:
		for failure in failures.slice(0, 20):
			push_error(failure)
		print("FAIL data parity: %d mismatches" % failures.size())
		quit(1)

func _test_blocked_idle_yield() -> void:
	# Reduced geometry from the user's blocked slot. Pure step selection only.
	var input: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/blocked_idle_yield.json"))
	var original_destination: Dictionary = input.destination.duplicate()
	input.destination = Navigation.idle_yield_target(input.agent, input.neighbors)
	_equal(Navigation.segment_is_clear(input.agent.position, input.destination, input.neighbors), true, "idle yield target has a clear approach")
	_equal(Navigation.plan_route(input.agent.position, input.destination, input.neighbors, _allowed).is_empty(), false, "blocked idle has a route to its yield target")
	var result := Navigation.choose_step(input, _allowed)
	_equal(result.blocked, false, "idle can yield to a stationary blocked collector")
	for other in input.neighbors:
		var candidate: Dictionary = input.agent.duplicate(true)
		candidate.velocity = result.velocity
		candidate.stopAfterSeconds = input.deltaSeconds
		var actual_other: Dictionary = other.duplicate(true)
		actual_other.velocity = other.tickVelocity
		actual_other.stopAfterSeconds = input.deltaSeconds
		_equal(Navigation.closest_approach(candidate, actual_other, input.deltaSeconds) >= minf(Navigation.MINIMUM_SEPARATION, Movement.Geo.distance(candidate.position, other.position)) - 1e-7, true, "idle yield protects actual tick paths")
	for other in input.neighbors:
		other.waitingForClearance = false
	input.destination = original_destination
	_equal(Navigation.choose_step(input, _allowed).blocked, true, "moving worker forecast remains protected")

func _test_current_save() -> void:
	# Isolated files only; never read or overwrite the player's actual slots.
	var directory := "user://migration-save-check-%s-%s" % [OS.get_process_id(), Time.get_ticks_usec()]
	var repository := Saves.new(directory)
	var state := State.create_initial()
	state.phase = "paused"
	state.inventory.amounts.gold = 12
	_equal(repository.save_slot(1, state, "2026-11-05T00:00:00Z").ok, true, "save current slot")
	var loaded := repository.read_slot(1)
	_equal(loaded.status, "valid", "read current slot")
	if loaded.status == "valid":
		_equal(loaded.save.gameState, Saves.normalized_state(state), "current save round trip")
		loaded.save.gameState.inventory.amounts.food = 2
		Commands.apply(loaded.save.gameState, {"type": "recruit-gatherer", "position": {"x": 80, "y": 84}})
		_equal(loaded.save.gameState.units.size(), 3, "purchase uses decoded JSON numbers")
		_equal(loaded.save.gameState.inventory.amounts.food, 0, "post-load purchase cost")
		_equal(loaded.save.gameState.units[2].id, "unit-gatherer-02", "post-load ID counter")
	_equal(state.phase, "paused", "saving does not mutate live phase")
	_equal(repository.save_slot(2, state, "2026-11-05T00:00:00Z").ok, true, "save second slot")
	_equal(repository.delete_slot(1), OK, "delete selected slot")
	_equal(repository.read_slot(1).status, "empty", "selected slot deleted")
	_equal(repository.read_slot(2).status, "valid", "other slot preserved")
	_equal(repository.delete_slot(2), OK, "cleanup isolated second slot")
	_equal(DirAccess.remove_absolute(directory), OK, "cleanup isolated test directory")

func _test_purchases(samples: Array) -> void:
	for sample in samples:
		var state := State.create_initial()
		state.inventory.amounts = sample.setup.get("amounts", {"food": 100, "wood": 100, "stone": 100, "spark": 100, "gold": 100}).duplicate()
		state.progression.unlockedTechnologies = sample.setup.get("technologies", []).duplicate()
		if sample.setup.has("secondRole"):
			state.units[1].role = sample.setup.secondRole
		if sample.setup.has("secondHealth"):
			state.units[1].health = sample.setup.secondHealth
		if sample.setup.has("axeLevel"):
			state.toolLevels.axe = sample.setup.axeLevel
		for action in sample.actions:
			Commands.apply(state, action)
		for key in sample.result:
			_equal(state[key], sample.result[key], sample.name + ": " + key)

func _allowed(point: Dictionary) -> bool:
	return point.x >= 2 and point.x <= 158 and point.y >= 2 and point.y <= 158

func _test_support(reference: Dictionary) -> void:
	for sample in reference.approaches:
		_equal(Movement.resource_approach(sample.position, sample.resource), sample.result, "resource approach inside/outside radius")
	for sample in reference.projection:
		_equal(Movement.outside_totem(sample.position, {"x": 80, "y": 80}, "unit-a"), sample.clearance, "totem clearance")
		_equal(Movement.project_within(sample.position, {"x": 80, "y": 80}, 15), sample.recruitment, "recruitment projection")
	for sample in reference.navigation:
		_equal(Navigation.choose_step(sample.input, _allowed), sample.result, "navigation step")
		_equal(Navigation.idle_yield_target(sample.input.agent, sample.input.neighbors), sample.yieldTarget, "yield")
	for sample in reference.routes:
		_equal(Navigation.plan_route(sample.start, sample.goal, sample.obstacles, _allowed), sample.result, "visibility route")
	for sample in reference.segments:
		_equal(Navigation.segment_is_clear(sample.start, sample.end, sample.obstacles), sample.result, "static segment clearance")
	var allowed_calls := [0]
	var allowed := func(point: Dictionary) -> bool:
		allowed_calls[0] += 1
		return _allowed(point)
	var invalid_route := Navigation.plan_route({"x": 80, "y": 80}, {"x": 162, "y": 80}, [{"id": "obstacle", "position": {"x": 82, "y": 80}}], allowed)
	_equal(invalid_route, [], "outside goal has no route")
	_equal(allowed_calls[0], 1, "reject impossible goal before graph construction")
	for sample in reference.idle:
		_equal(Idle.choose_destination(sample.seed, sample.id, sample.step, sample.position, sample.area, sample.neighbors), sample.destination, "idle destination")
		_equal(Idle.wait_seconds(sample.seed, sample.id, sample.step), sample.wait, "idle wait")
		_equal(Idle.range_entry(sample.position, sample.area), sample.entry, "range entry")
	for sample in reference.combatSlots:
		_equal(CombatPositions.assign(sample.target, sample.attackers, sample.occupied, func(_attacker, point): return _allowed(point)), sample.result, "combat positions")
	for sample in reference.awareness:
		_equal(Awareness.choose_calls(sample.units, sample.entities, 18, 18), sample.result, "entity calls")
	for sample in reference.gathering:
		_equal(Rules.choose_gather_task(sample.input), sample.result, "gather selection")

func _test_economy(reference: Dictionary) -> void:
	for population in reference.recruitment.size():
		_equal(Economy.recruitment_cost(population), reference.recruitment[population], "recruitment cost %d" % population)
	for item in reference.specializations:
		_equal(Economy.SPECIALIZATIONS[item].limit, reference.specializations[item].limit, "specialization limit: " + item)
		for count in reference.specializations[item].costs.size():
			_equal(Economy.specialization_cost(item, count), reference.specializations[item].costs[count], "specialization cost: %s/%d" % [item, count])
	for count in reference.shields.size():
		_equal(Economy.shield_cost(count), reference.shields[count], "shield cost %d" % count)
	for tool in reference.upgrades:
		for level in reference.upgrades[tool].size():
			_equal(Economy.tool_upgrade(tool, level), reference.upgrades[tool][level], "tool: %s/%d" % [tool, level])
	_equal(Progression.TECHNOLOGIES, reference.technologies, "technologies")
	_equal(Progression.BALANCE, reference.progression, "progression balance")
	for sample in reference.bonuses:
		_equal(Economy.rolls_bonus(sample.seed, sample.tick, sample.unitId, sample.nodeId, sample.tool, sample.level), sample.result, "deterministic tool bonus")

func _test_transactions() -> void:
	var amounts := {"food": 10, "wood": 10, "stone": 10, "spark": 1, "gold": 2}
	var original: Dictionary = amounts.duplicate()
	_equal(Economy.spend(amounts, Economy.TOOL_COSTS[10]), false, "insufficient spark fails atomically")
	_equal(amounts, original, "failed mixed purchase preserves all resources")
	amounts.spark = 2
	_equal(Economy.spend(amounts, Economy.TOOL_COSTS[10]), true, "mixed purchase succeeds")
	_equal(amounts, {"food": 10, "wood": 10, "stone": 0, "spark": 0, "gold": 0}, "successful mixed cost deducted exactly")
	_equal(Economy.tool_upgrade("axe", 11), null, "no upgrade past 10")
	_equal(Economy.node_tool_requirement_met({"source": "stone-vein", "tier": 2}, {"hammer": 4}), false, "stone II locked")
	_equal(Economy.node_tool_requirement_met({"source": "stone-vein", "tier": 2}, {"hammer": 5}), true, "stone II unlocked")
	var progression := Progression.create_initial()
	_equal(Progression.award_experience(progression, 36), 2, "multiple levels from 36 XP")
	_equal(progression, {"level": 2, "experience": 0, "experienceToNextLevel": 36, "technologyPoints": 2, "unlockedTechnologies": []}, "XP remainder and points")
	_equal(Progression.unlock(progression, "mage"), true, "mage unlock at level 2")
	var after: Dictionary = progression.duplicate(true)
	_equal(Progression.unlock(progression, "mage"), false, "duplicate unlock rejected")
	_equal(progression, after, "duplicate unlock preserves points")
	var insufficient := Progression.create_initial()
	insufficient.technologyPoints = 5
	_equal(Progression.unlock(insufficient, "shield"), false, "technology requires level despite points")

func _equal(actual: Variant, expected: Variant, context: String) -> void:
	checks += 1
	if actual is Dictionary and expected is Dictionary:
		if actual.size() != expected.size():
			failures.append(context + ": dictionary size differs")
		for key in expected:
			if not actual.has(key):
				failures.append(context + ": missing " + key)
			else:
				_equal(actual[key], expected[key], context + "." + key)
	elif actual is Array and expected is Array:
		if actual.size() != expected.size():
			failures.append(context + ": array size differs (%s vs %s)" % [actual.size(), expected.size()])
		for index in mini(actual.size(), expected.size()):
			_equal(actual[index], expected[index], context + "[%d]" % index)
	elif (actual is int or actual is float) and (expected is int or expected is float):
		if absf(float(actual) - float(expected)) > 0.000000001:
			failures.append(context + ": %s != %s" % [actual, expected])
	elif actual != expected:
		failures.append(context + ": %s != %s" % [actual, expected])
