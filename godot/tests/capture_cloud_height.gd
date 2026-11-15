extends SceneTree
const State = preload("res://scripts/simulation/game_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1000, 800)
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
	var state := State.create_initial("cloud-height")
	var world := preload("res://scenes/WorldView.tscn").instantiate()
	root.add_child(world)
	world.setup(state)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	root.add_child(camera)
	camera.make_current()
	var totem := preload("res://scenes/world/Totem3D.tscn").instantiate()
	root.add_child(totem)
	var index := 0
	for kind in ["clearing", "meadow", "forest"]:
		var biome: Dictionary = state.biomes.filter(func(b): return b.id == kind)[0]
		var center := Vector3(biome.region.x, 0, biome.region.y)
		var cloud: Node3D = world.cloud_variants[index].instantiate()
		root.add_child(cloud)
		cloud.position = center
		totem.position = center + Vector3(4, 2, 0)
		state.units[0].position = {"x": center.x - 3, "y": center.z}
		world.sync(state)
		var focus := center + Vector3.UP * 10
		camera.position = focus + Vector3(1, tan(deg_to_rad(35)) * sqrt(2), 1).normalized() * 120
		camera.look_at(focus)
		for zoom in [36, 72]:
			camera.size = zoom
			cloud.present({"phase": "raining", "phaseElapsedSeconds": 0.5})
			await process_frame
			await RenderingServer.frame_post_draw
			var capture := root.get_texture().get_image()
			capture.save_png("res://reports/cloud-height-%s-%d.png" % [kind, zoom])
			# Confirm the soft shadow actually survives the biome depth buffer.
			cloud.get_node("GroundShadow").visible = false
			await process_frame
			await RenderingServer.frame_post_draw
			var unshadowed := root.get_texture().get_image()
			var screen := camera.unproject_position(center) * Vector2(capture.get_size()) / root.get_visible_rect().size
			var changed := 0
			for y in range(int(screen.y) - 15, int(screen.y) + 15):
				for x in range(int(screen.x) - 15, int(screen.x) + 15):
					if unshadowed.get_pixel(x, y).get_luminance() - capture.get_pixel(x, y).get_luminance() > 0.005:
						changed += 1
			if changed < 50:
				push_error("Ground shadow not visible on %s at zoom %d" % [kind, zoom])
				quit(1)
				return
			cloud.get_node("GroundShadow").visible = true
		cloud.free()
		index += 1
	world.free()
	totem.free()
	camera.free()
	print("PASS cloud height captures: three biomes, two zooms")
	quit()
