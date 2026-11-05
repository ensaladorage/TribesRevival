class_name TribeGeometry
extends RefCounted
## Double-precision logical coordinates; Vector2 is reserved for presentation.

static func distance(first: Dictionary, second: Dictionary) -> float:
	var dx: float = first.x - second.x
	var dy: float = first.y - second.y
	return sqrt(dx * dx + dy * dy)

static func length(vector: Dictionary) -> float:
	return sqrt(float(vector.x) * vector.x + float(vector.y) * vector.y)

static func velocity_towards(point: Dictionary, target: Dictionary, speed: float) -> Dictionary:
	var distance_to_target := distance(point, target)
	if distance_to_target <= 1e-8:
		return {"x": 0.0, "y": 0.0}
	return {"x": (target.x - point.x) / distance_to_target * speed, "y": (target.y - point.y) / distance_to_target * speed}

static func at(point: Dictionary, velocity: Dictionary, time: float) -> Dictionary:
	return {"x": point.x + velocity.x * time, "y": point.y + velocity.y * time}

static func stable_sorted(values: Array, less: Callable) -> Array:
	# JS Array.sort is stable; Godot Array.sort_custom makes no such guarantee.
	var decorated: Array = []
	for index in values.size():
		decorated.append({"value": values[index], "order": index})
	decorated.sort_custom(func(a, b):
		if less.call(a.value, b.value):
			return true
		if less.call(b.value, a.value):
			return false
		return a.order < b.order)
	return decorated.map(func(entry): return entry.value)
