extends SceneTree
## Cross-language data parity. No scene rendering, simulation steps, or input.

const Random = preload("res://scripts/simulation/seeded_random.gd")
const State = preload("res://scripts/simulation/game_state.gd")
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
	if failures.is_empty():
		print("PASS data parity: %d comparisons against TypeScript; 4 complete initial worlds; no gameplay ticks" % checks)
		quit(0)
	else:
		for failure in failures.slice(0, 20):
			push_error(failure)
		print("FAIL data parity: %d mismatches" % failures.size())
		quit(1)

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
