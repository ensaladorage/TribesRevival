extends SceneTree
## Cross-language data parity. No scene rendering, simulation steps, or input.

const Random = preload("res://scripts/simulation/seeded_random.gd")
const State = preload("res://scripts/simulation/game_state.gd")
const Economy = preload("res://scripts/simulation/economy.gd")
const Progression = preload("res://scripts/simulation/progression.gd")
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
	if failures.is_empty():
		print("PASS data parity: %d comparisons against TypeScript; 4 complete initial worlds; no gameplay ticks" % checks)
		quit(0)
	else:
		for failure in failures.slice(0, 20):
			push_error(failure)
		print("FAIL data parity: %d mismatches" % failures.size())
		quit(1)

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
