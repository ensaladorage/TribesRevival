class_name TribeWeatherSystem
extends RefCounted

const Random = preload("res://scripts/simulation/seeded_random.gd")
const Geo = preload("res://scripts/simulation/geometry.gd")
const TARGET_TYPES := ["clearing", "meadow", "forest"]

static func _choose_target(state: Dictionary, cloud_index: int) -> Variant:
	var types := TARGET_TYPES.duplicate()
	var random := Random.new("%s:weather-type-cycle:%s" % [state.seed, int(floor(float(cloud_index) / TARGET_TYPES.size()))])
	for index in range(types.size() - 1, 0, -1):
		var swap_index := random.next_int(0, index)
		var temporary: String = types[index]
		types[index] = types[swap_index]
		types[swap_index] = temporary
	var target_type: String = types[cloud_index % TARGET_TYPES.size()]
	var candidates: Array = []
	for biome in state.biomes:
		if biome.id != target_type:
			continue
		for resource in state.resources:
			if resource.get("biomeInstanceId") == biome.instanceId and resource.type in ["food", "wood"]:
				candidates.append(biome)
				break
	candidates.sort_custom(func(a, b): return a.instanceId < b.instanceId)
	if candidates.is_empty():
		return null
	return candidates[Random.new("%s:weather-target:%s" % [state.seed, cloud_index]).next_int(0, candidates.size() - 1)]

static func _spawn(state: Dictionary) -> void:
	var index: int = state.weather.nextCloudIndex
	state.weather.nextCloudIndex += 1
	var target: Variant = _choose_target(state, index)
	if target == null:
		return
	state.weather.clouds.append({"id": "weather-cloud-%03d" % (index + 1), "position": {"x": target.region.x + sqrt(0.5) * 64.0, "y": target.region.y + sqrt(0.5) * 64.0}, "targetBiomeInstanceId": target.instanceId, "phase": "approaching", "phaseElapsedSeconds": 0.0, "rainRemainingSeconds": 0.0})

static func move_point(point: Dictionary, destination: Dictionary, maximum: float) -> bool:
	var distance := Geo.distance(point, destination)
	if distance <= maximum or distance < 1e-8:
		point.merge(destination, true)
		return true
	point.x += (destination.x - point.x) / distance * maximum
	point.y += (destination.y - point.y) / distance * maximum
	return false

static func _advance_cloud(state: Dictionary, cloud: Dictionary, delta: float) -> bool:
	var target: Variant = null
	for biome in state.biomes:
		if biome.instanceId == cloud.targetBiomeInstanceId:
			target = biome
			break
	if target == null:
		return false
	var center := {"x": target.region.x, "y": target.region.y}
	if cloud.phase == "approaching":
		if move_point(cloud.position, center, 2.5 * delta):
			cloud.phase = "raining"
			cloud.phaseElapsedSeconds = 0.0
			cloud.rainRemainingSeconds = 6.0
			for resource in state.resources:
				if resource.get("biomeInstanceId") == target.instanceId and resource.type in ["food", "wood"] and resource.amount <= 0:
					resource.amount = maxf(resource.maxAmount, 0)
		return true
	if cloud.phase == "raining":
		cloud.phaseElapsedSeconds += delta
		cloud.rainRemainingSeconds = maxf(0, cloud.rainRemainingSeconds - delta)
		cloud.position.x -= sqrt(0.5) * 0.75 * delta
		cloud.position.y -= sqrt(0.5) * 0.75 * delta
		if cloud.rainRemainingSeconds <= 1e-9:
			cloud.rainRemainingSeconds = 0.0
			cloud.phase = "departing"
			cloud.phaseElapsedSeconds = 0.0
		return true
	return not move_point(cloud.position, {"x": center.x - sqrt(0.5) * 180.0, "y": center.y - sqrt(0.5) * 180.0}, 2.5 * delta)

static func update(state: Dictionary, delta: float) -> void:
	if not is_finite(delta) or delta <= 0:
		return
	state.weather.nextCloudInSeconds -= delta
	while state.weather.nextCloudInSeconds <= 1e-9:
		_spawn(state)
		state.weather.nextCloudInSeconds += 30.0
	for index in range(state.weather.clouds.size() - 1, -1, -1):
		if not _advance_cloud(state, state.weather.clouds[index], delta):
			state.weather.clouds.remove_at(index)
