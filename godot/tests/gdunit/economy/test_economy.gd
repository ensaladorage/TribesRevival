extends GdUnitTestSuite

const Economy = preload("res://scripts/simulation/economy.gd")

func test_spend_rejects_insufficient_resources_without_changes() -> void:
	var resources := {"wood": 1}
	assert_bool(Economy.spend(resources, {"wood": 2})).is_false()
	assert_dict(resources).is_equal({"wood": 1})

func test_spend_deducts_the_cost() -> void:
	var resources := {"wood": 4}
	assert_bool(Economy.spend(resources, {"wood": 2})).is_true()
	assert_dict(resources).is_equal({"wood": 2})
