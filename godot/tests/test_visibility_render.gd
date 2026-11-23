extends SceneTree
## Reproducible real-world captures, with the actual totem, trees and characters.
const State = preload("res://scripts/simulation/game_state.gd")
const World = preload("res://scenes/WorldView.tscn")
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(960, 720)
	# Reuse the real game's ground and lighting without running its simulation/UI.
	var main := preload("res://scenes/main.tscn").instantiate()
	for name in ["Ground", "WorldEnvironment", "Sun"]:
		var node: Node = main.get_node(name)
		main.remove_child(node)
		node.owner = null
		root.add_child(node)
	main.world_view.free()
	main.hud.free()
	main.menus.free()
	main.free()
	var state := State.create_initial("natural-visibility-capture")
	var world := World.instantiate()
	root.add_child(world)
	world.setup(state)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	root.add_child(camera)
	camera.make_current()
	var totem := preload("res://scenes/world/Totem3D.tscn").instantiate()
	root.add_child(totem)
	for biome in ["forest", "meadow"]:
		var resource: Dictionary = state.resources.filter(func(r): return r.source == "tree" and r.biome == biome)[0]
		var tree: Node3D = world._views[resource.id]
		var sprite: AnimatedSprite3D = tree.canopy_sprite()
		var focus := tree.global_position + Vector3.UP * 2
		camera.position = focus + Vector3(1, tan(deg_to_rad(35)) * sqrt(2), 1).normalized() * 120
		camera.look_at(focus)
		# Place the visible body behind the crown independently of the terrain height
		# and the actor atlas padding. Only the view moves in this render test.
		var unit: Dictionary = state.units[0]
		var previous := {unit.id: {"x": unit.position.x + 1.0, "y": unit.position.y}}
		world.sync(state, previous)
		var actor: Node3D = world._views[state.units[0].id]
		var body: AnimatedSprite3D = actor.get_node("Body/Sprite")
		if not body.flip_h:
			failures += 1
			push_error("Body should face left for mirrored occlusion")
		var samples: PackedVector3Array = world._occlusion.sprite_samples(body, camera)
		var center: Vector2 = world._occlusion.projected_bounds(samples, camera).get_center()
		var body_center := camera.global_basis.x * center.x + camera.global_basis.y * center.y
		body_center += camera.global_basis.z * samples[0].dot(camera.global_basis.z)
		var crown_point: Vector3 = world._occlusion.sprite_point(sprite, Vector2(0.5, 0.42), camera)
		actor.global_position += crown_point - camera.global_basis.z * 2.0 - body_center
		totem.position = tree.position - camera.global_basis.x * 5 + Vector3.UP * 2
		for zoom in [36.0, 18.0]:
			camera.size = zoom
			tree.update_holes({}, camera, 1.0)
			await _capture("%s-%d-opaque" % [biome, int(zoom)])
			var start_frame := sprite.frame
			var elapsed := 0.0
			var begin := Time.get_ticks_usec()
			for step in 20:
				world.update_occlusion(camera, 0.02)
				elapsed += 0.02
				await create_timer(0.02).timeout
			print("Occlusion capture %s zoom %d: holes %s, elapsed wall %d ms" % [biome, zoom, tree._holes.size(), (Time.get_ticks_usec() - begin) / 1000])
			if tree._holes.is_empty():
				failures += 1
				push_error("Real canopy did not fade over body")
			if start_frame == sprite.frame:
				failures += 1
				push_error("Tree animation did not advance")
			await _capture("%s-%d-faded" % [biome, int(zoom)])
		# Test the real totem alone, behind and in front of the same canopy.
		for view in world._views.values():
			if view.has_meta("kind"):
				view.visible = false
		var crown: Vector3 = world._occlusion.sprite_point(sprite, Vector2(0.5, 0.42), camera)
		totem.position = crown - camera.global_basis.z * 6
		tree.update_holes({}, camera, 1.0)
		world.update_occlusion(camera, 0.2)
		if not tree._holes.is_empty():
			failures += 1
			push_error("Totem behind canopy must not trigger fade")
		totem.position += camera.global_basis.z * 12
		world.update_occlusion(camera, 0.5)
		if not tree._holes.is_empty():
			failures += 1
			push_error("Totem in front must not trigger fade")
		for view in world._views.values():
			if view.has_meta("kind"):
				view.visible = true
	world.free()
	totem.free()
	camera.free()
	print("%s visibility render: forest/meadow at two zooms, real animation and occlusion" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/visibility-%s.png" % label)
