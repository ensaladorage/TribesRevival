extends SceneTree
const Session = preload("res://scripts/simulation/game_session.gd")
const TerrainView = preload("res://scripts/view/terrain_projection.gd")
const World = preload("res://scenes/WorldView.tscn")
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func run() -> void:
	var session := Session.new("respawn-interpolation")
	var state: Dictionary = session.state
	state.resources = []
	state.biomes = []
	state.decorations = []
	state.weather.clouds = []
	var enemy: Dictionary = state.barbarians[0]
	var sheep: Dictionary = state.animals[0]
	state.barbarians = [enemy]
	state.animals = [sheep]
	for actor in [enemy, sheep]:
		actor.position = {"x": 15.0, "y": 145.0}
		actor.isAlive = false
		actor.health = 0.0
		actor.respawnRemainingSeconds = 0.10
	var world := World.instantiate()
	root.add_child(world)
	world.setup(state)
	# Dead actors must not render or contribute interpolation origins.
	session.advance(0.05)
	world.sync(state, session.previous_positions, 0.5)
	for actor in [enemy, sheep]:
		check(not session.previous_positions.has(actor.id), "Dead actor has no interpolation origin")
		check(not world._views.has(actor.id), "Dead actor stays hidden")
	# Expire the actual respawn timer, including its spawn-cycle change.
	session.advance(0.05)
	for alpha in [0.0, 0.25, 0.5, 0.75, 1.0]:
		world.sync(state, session.previous_positions, alpha)
		for actor in [enemy, sheep]:
			check(actor.isAlive and actor.spawnCycle == 1, "Actual respawn completed")
			var expected := TerrainView.world(actor.position, state.terrain)
			check(world._views[actor.id].position.is_equal_approx(expected), "Respawn appears at current location for every render frame")
	# Subsequent living movement must still interpolate normally.
	session.advance(0.05)
	for actor in [enemy, sheep]:
		var previous: Dictionary = session.previous_positions[actor.id]
		actor.position = {"x": previous.x + 0.1, "y": previous.y + 0.05}
	world.sync(state, session.previous_positions, 0.5)
	for actor in [enemy, sheep]:
		var previous: Dictionary = session.previous_positions[actor.id]
		var expected := TerrainView.world({"x": lerpf(previous.x, actor.position.x, 0.5), "y": lerpf(previous.y, actor.position.y, 0.5)}, state.terrain)
		check(world._views[actor.id].position.is_equal_approx(expected), "Living movement remains interpolated")
	world.free()
	for failure in failures: push_error(failure)
	print("%s respawn interpolation: barbarian and sheep, five render fractions and normal movement" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
