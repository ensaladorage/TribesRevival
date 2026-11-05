class_name TribeGameState
extends RefCounted
## Serializable logical data. Coordinates x/y map to Godot x/z only in views.

const WORLD_SIZE := 160.0
const EDGE_PADDING := 2.0
const DEFAULT_SEED := "totem-tribes-hito-2a"

static func create_initial(seed_text: String = DEFAULT_SEED) -> Dictionary:
	return {
		"version": 17, "seed": seed_text, "tick": 0, "phase": "playing",
		"totem": {
			"position": {"x": 80.0, "y": 80.0}, "dragTarget": null,
			"destination": null, "moving": false, "isCarried": false,
			"commandRadius": 10.0, "dangerRadius": 18.0, "bondEnergy": 100.0,
		},
	}

static func clamp_position(point: Dictionary) -> Dictionary:
	return {
		"x": clampf(float(point.x), EDGE_PADDING, WORLD_SIZE - EDGE_PADDING),
		"y": clampf(float(point.y), EDGE_PADDING, WORLD_SIZE - EDGE_PADDING),
	}
