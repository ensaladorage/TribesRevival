extends GdUnitTestSuite

const Combat = preload("res://scripts/simulation/combat_rules.gd")

func test_damage_does_not_reduce_health_below_zero() -> void:
	var result: Dictionary = Combat.deal_damage("minion", "barbarian", {"health": 2.0}, 5.0)
	assert_float(result.health).is_equal(0.0)
	assert_float(result.damageApplied).is_equal(2.0)
	assert_bool(result.defeated).is_true()

func test_heal_does_not_exceed_maximum() -> void:
	var result: Dictionary = Combat.heal({"health": 3.0, "maxHealth": 4.0}, 5.0)
	assert_float(result.health).is_equal(4.0)
	assert_float(result.healingApplied).is_equal(1.0)
