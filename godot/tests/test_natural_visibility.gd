extends SceneTree
const State = preload("res://scripts/simulation/game_state.gd")
const World = preload("res://scenes/WorldView.tscn")
const Occlusion = preload("res://scripts/view/sprite_occlusion.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for index in 8:
		var state := State.create_initial("clearance-%d" % index)
		var original := JSON.stringify(state)
		var world := World.instantiate()
		root.add_child(world)
		world.setup(state)
		var first := _layout(world)
		for child in world.get_children():
			if not child.has_meta("decoration_id"):
				continue
			var point := Vector2(child.position.x, child.position.z / world.TerrainView.DEPTH_SCALE)
			_check(world._decoration_fits(point, child.decoration_clearance_radius * child.scale.x), "Decoration clears all resource footprints")
			var source: Dictionary = state.decorations.filter(func(d): return d.id == child.get_meta("decoration_id"))[0]
			var biome: Dictionary = state.biomes.filter(func(b): return b.instanceId == source.biomeInstanceId)[0]
			_check(world.Footprint.contains(biome.region, point), "Relocated decoration remains in its biome")
		world.setup(JSON.parse_string(original))
		_check(first == _layout(world), "Same layout after save and rebuild")
		_check(original == JSON.stringify(state), "Presentation leaves state untouched")
		for resource in state.resources:
			resource.amount = 0
		world.setup(state)
		_check(first == _layout(world), "Depletion does not move decoration")
		# No valid point: only the presentation is omitted.
		world._resource_clearances.clear()
		world._resource_clearances.append(Vector3(0, 0, 100))
		var before := world.get_child_count()
		world._create_decoration({"id": "blocked", "kind": "bush", "biome": "forest", "biomeInstanceId": "tiny", "position": {"x": 0, "y": 0}, "scale": 1.4}, "blocked", [{"instanceId": "tiny", "region": {"x": 0, "y": 0, "size": 4, "cells": [{"x": 0, "y": 0}]}}])
		_check(world.get_child_count() == before, "No placement after twelve candidates omits decoration")
		world.free()
	_test_occlusion()
	print("%s natural visibility: %d checks, eight seeds, projection and fade transitions" % ["PASS" if failures == 0 else "FAIL", checks])
	quit(0 if failures == 0 else 1)

func _layout(world: Node3D) -> Dictionary:
	var result := {}
	for child in world.get_children():
		if child.has_meta("decoration_id"):
			result[child.get_meta("decoration_id")] = child.position
	return result

func _test_occlusion() -> void:
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(0, 0, 10)
	var sprite := Sprite3D.new()
	root.add_child(sprite)
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.fill_rect(Rect2i(4, 4, 8, 8), Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.pixel_size = 1
	var helper := Occlusion.new()
	var region := Rect2(0, 0, 1, 1)
	_check(helper.covers(sprite, region, PackedVector3Array([Vector3(0, 0, -2)]), camera), "Opaque canopy hides rear body")
	_check(not helper.covers(sprite, region, PackedVector3Array([Vector3(0, 0, 2)]), camera), "Front body does not fade tree")
	_check(not helper.covers(sprite, region, PackedVector3Array([Vector3(6, 6, -2)]), camera), "Transparent margin does not trigger")
	# The broad phase must never reject an overlap accepted by opaque pixels.
	for angle in [0.0, 0.5, 1.2]:
		camera.rotation = Vector3(-0.4, angle, 0)
		for x in range(-4, 21):
			var point: Vector3 = helper.sprite_point(sprite, Vector2(x / 16.0, 0.5), camera) - camera.global_basis.z * 2
			var points := PackedVector3Array([point])
			var exact: bool = helper.covers(sprite, region, points, camera)
			var candidate: bool = helper.sprite_bounds(sprite, camera).intersects(helper.projected_bounds(points, camera))
			_check(not exact or candidate, "Projected broad phase conservatively includes opaque overlap")
	camera.rotation = Vector3.ZERO
	_check(not helper.covers(sprite, Rect2(0, 0, 0.2, 0.2), PackedVector3Array([Vector3(0, 0, -2)]), camera), "Editable canopy region excludes trunk")
	for zoom in [18.0, 36.0]:
		camera.size = zoom
		_check(helper.covers(sprite, region, PackedVector3Array([Vector3(0, 0, -2)]), camera), "Detection remains correct at either zoom")
	var tree := preload("res://scenes/world/Tree.tscn").instantiate()
	var other := preload("res://scenes/world/Tree2.tscn").instantiate()
	root.add_child(tree)
	root.add_child(other)
	var canopy: SpriteBase3D = tree.canopy_sprite()
	var second: SpriteBase3D = other.canopy_sprite()
	tree.update_holes({1: Vector3.ZERO}, camera, 0.15)
	_check(tree._holes.size() == 1 and is_equal_approx(tree._holes[1].amount, 1.0), "Hole opens in 150 ms")
	_check(other._holes.is_empty(), "Hole state is per instance")
	tree.update_holes({1: Vector3.ZERO, 2: Vector3.ONE}, camera, 0.15)
	_check(tree._holes.size() == 2, "Multiple characters retain separate circles")
	_check(is_equal_approx(canopy.modulate.a, 1.0), "Tree never becomes globally transparent")
	tree.update_holes({}, camera, 0.15)
	_check(tree._holes.size() == 2, "Restore waits 150 ms")
	tree.update_holes({}, camera, 0.25)
	_check(tree._holes.is_empty() and canopy.material_override == null, "Native material restored after closure")
	_check(not canopy.no_depth_test and canopy.render_priority == 0 and canopy.is_playing(), "Depth-tested animation remains active")
	for node in [tree, other, sprite, camera]:
		node.free()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

