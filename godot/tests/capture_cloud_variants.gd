extends SceneTree
## Render the four editable compositions with the game's isometric angle.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1100, 750)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 40
	root.add_child(camera)
	var center := Vector3(0, 15, 0)
	camera.position = center + Vector3(1, tan(deg_to_rad(35)) * sqrt(2), 1).normalized() * 100
	camera.look_at(center)
	camera.make_current()
	for index in 4:
		var path := "res://scenes/world/Cloud%s.tscn" % ("" if index == 0 else str(index + 1))
		var cloud := load(path).instantiate() as Node3D
		root.add_child(cloud)
		cloud.position = camera.global_basis.x * (-10 if index % 2 == 0 else 10) + camera.global_basis.y * (6 if index < 2 else -6)
		cloud.present({"phase": "approaching", "phaseElapsedSeconds": 0.0})
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/cloud-compositions.png")
	print("PASS captured four cloud compositions")
	quit()
