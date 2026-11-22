extends RefCounted
## Unobstructed arena for existing combat and economy reference scenarios.
static func rows() -> Array:
	var result: Array = []
	result.resize(105)
	result.fill("1".repeat(105))
	return result
