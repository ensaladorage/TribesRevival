class_name TribeGameState
extends RefCounted
## Serializable logical data. Coordinates x/y map to Godot x/z only in views.

const WORLD_SIZE := 160.0
const EDGE_PADDING := 2.0
const DEFAULT_SEED := "totem-tribes-hito-2a"
const Random = preload("res://scripts/simulation/seeded_random.gd")
const Catalog = preload("res://scripts/simulation/world_catalog.gd")

static func empty_amounts() -> Dictionary:
	return {"food": 0, "wood": 0, "stone": 0, "spark": 0, "gold": 0}

static func create_unit(id: String, role: String, point: Dictionary) -> Dictionary:
	return {
		"id": id, "idleMovement": {"destination": null, "waitRemainingSeconds": 0, "step": 0},
		"position": point.duplicate(), "role": role, "hasShield": false,
		"health": 4, "maxHealth": 4, "healingProgressSeconds": 0, "state": "formation",
		"cargo": {"amounts": empty_amounts(), "capacity": 4},
		"task": {"kind": "idle", "targetResourceId": null, "destination": null, "cause": "no-valid-resource"},
		"cancelledTargetId": null, "actionProgressSeconds": 0,
		"attackCooldownRemainingSeconds": 0, "attackLockRemainingSeconds": 0, "withdrawAfterAttack": false,
	}

static func create_initial(seed_text: String = DEFAULT_SEED) -> Dictionary:
	var blueprint := Catalog.create_blueprint(seed_text)
	var roster_random := Random.new(seed_text + ":initial-roster")
	var second_role := "lumberjack" if roster_random.next_int(0, 1) == 0 else "hunter"
	return {
		"version": 17, "seed": seed_text, "tick": 0, "phase": "playing",
		"totem": {
			"position": {"x": 80.0, "y": 80.0}, "dragTarget": null,
			"destination": null, "moving": false, "isCarried": false,
			"commandRadius": 10.0, "dangerRadius": 18.0, "bondEnergy": 100.0,
		},
		"units": [create_unit("unit-gatherer-01", "gatherer", {"x": 84, "y": 80}), create_unit("unit-initial-specialist-02", second_role, {"x": 76, "y": 80})],
		"corpses": [], "barbarians": Catalog.create_barbarians(seed_text),
		"animals": Catalog.create_rabbits(seed_text, blueprint.biomes), "barbarianCorpses": [],
		"purchaseCounts": {"gatherer": 0, "lumberjack": 0, "hunter": 0, "guardian": 0, "artisan": 0, "mage": 0},
		"toolLevels": {"axe": 0, "hammer": 0, "sword": 0},
		"progression": {"level": 0, "experience": 0, "experienceToNextLevel": 12, "technologyPoints": 0, "unlockedTechnologies": []},
		"biomes": blueprint.biomes, "resources": blueprint.resources, "decorations": blueprint.decorations,
		"drops": [], "nextDropId": 1, "campfires": [], "nextCampfireId": 1,
		"inventory": {"amounts": empty_amounts()}, "effects": [], "nextEffectId": 1,
		"alerts": [], "nextAlertId": 1, "weather": {"nextCloudInSeconds": 30, "nextCloudIndex": 0, "clouds": []},
	}

static func clamp_position(point: Dictionary) -> Dictionary:
	return {
		"x": clampf(float(point.x), EDGE_PADDING, WORLD_SIZE - EDGE_PADDING),
		"y": clampf(float(point.y), EDGE_PADDING, WORLD_SIZE - EDGE_PADDING),
	}
