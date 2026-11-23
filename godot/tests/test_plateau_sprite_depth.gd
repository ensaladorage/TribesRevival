extends SceneTree
## Pixel regression for an upright sprite in front of and behind a plateau face.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This pixel test requires a graphics renderer")
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var world := preload("res://scenes/WorldView.tscn").instantiate()
	root.add_child(world)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8
	camera.position = Vector3(0, sin(world.TerrainView.PITCH), cos(world.TerrainView.PITCH)) * 10
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	var wall := MeshInstance3D.new()
	wall.mesh = BoxMesh.new()
	wall.mesh.size = Vector3(4, 3, 1)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.GREEN
	wall.material_override = material
	wall.position = Vector3(0, 1.5, -0.5)
	root.add_child(wall)
	var sprite := Sprite3D.new()
	var image := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.offset.y = 16
	sprite.pixel_size = 0.05
	world.add_child(sprite)
	world._prepare_ground_sprite(sprite)
	var failures := 0
	for front in [true, false]:
		sprite.position = Vector3(2, 0.1, 0.15 if front else -1.15)
		await process_frame
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		# The sprite straddles the right edge. Only its inner half can be hidden.
		for inside in [true, false]:
			var point: Vector3 = sprite.position + camera.global_basis.y * 0.9
			point.x += -0.2 if inside else 0.2
			var pixel := frame.get_pixelv(Vector2i(camera.unproject_position(point)))
			var visible: bool = front or not inside
			if (visible and pixel.r < 0.8) or (not visible and pixel.g < 0.8):
				push_error("Plateau overlap front=%s inside=%s pixel=%s" % [front, inside, pixel])
				failures += 1
	print("%s plateau sprite pixels" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)
