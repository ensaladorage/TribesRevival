extends SceneTree
## Actual Compatibility rendering: natural depth, including the real totem mesh and outline.
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(160, 160)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 4
	camera.position = Vector3(0, 0, 10)
	root.add_child(camera)
	camera.make_current()
	var decoration := _sprite("res://scenes/world/DecorationBush.tscn", "Visual/Default/Sprite", Color.RED, 2)
	var resource := _sprite("res://scenes/world/Tree.tscn", "Visual/Default/Sprite", Color.GREEN, 0)
	await _expect(Color.RED, "Nearer decoration covers resource")
	decoration.visible = false
	var actor := _sprite("res://scenes/actors/Gatherer.tscn", "Body/Sprite", Color.BLUE, -2)
	await _expect(Color.GREEN, "Resource covers farther minion")
	actor.get_node("Body/Sprite").global_position.z = 2
	await _expect(Color.BLUE, "Nearer minion covers resource")
	actor.visible = false
	var enemy := _sprite("res://scenes/actors/Barbarian.tscn", "Body/Sprite", Color.BLUE, -2)
	await _expect(Color.GREEN, "Resource covers farther enemy")
	enemy.visible = false
	actor.visible = true
	var model := load("res://scenes/world/Totem3D.tscn").instantiate() as Node3D
	root.add_child(model)
	actor.visible = false
	resource.get_node("Visual/Default/Sprite").pixel_size = 10
	resource.get_node("Visual/Default/Sprite").global_position.z = 5
	model.position = Vector3(0, 2, -4)
	await _expect(Color.GREEN, "Nearer resource covers actual totem mesh and outline")
	var covered := root.get_texture().get_image()
	model.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var without_model := root.get_texture().get_image()
	if covered.get_data() != without_model.get_data():
		failures += 1
		push_error("Hidden totem or outline leaked through resource")
	model.visible = true
	resource.visible = false
	camera.size = 8
	await process_frame
	await RenderingServer.frame_post_draw
	var visible_model := root.get_texture().get_image()
	visible_model.save_png("res://reports/natural-depth-totem.png")
	model.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	if visible_model.get_data() == root.get_texture().get_image().get_data():
		failures += 1
		push_error("Real totem did not render")
	model.free()
	actor.visible = false
	resource.visible = false
	decoration.visible = true
	await _expect(Color.RED, "Decoration remains visible without resource")
	for node in [decoration, resource, actor, enemy]:
		node.free()
	print("%s sprite layers: 8 rendered depth checks, real totem mesh and outline" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _sprite(path: String, sprite_path: String, color: Color, depth: float) -> Node3D:
	var instance := load(path).instantiate() as Node3D
	root.add_child(instance)
	var sprite := instance.get_node(sprite_path) as SpriteBase3D
	var image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture := ImageTexture.create_from_image(image)
	if sprite is AnimatedSprite3D:
		sprite.stop()
		var frames := SpriteFrames.new()
		frames.add_frame("default", texture)
		sprite.sprite_frames = frames
		sprite.animation = "default"
	else:
		sprite.texture = texture
	sprite.transform = Transform3D.IDENTITY
	sprite.global_position = Vector3(0, 0, depth)
	sprite.offset = Vector2.ZERO
	sprite.pixel_size = 0.25
	return instance

func _expect(color: Color, label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var capture := root.get_texture().get_image()
	var actual := capture.get_pixel(capture.get_width() / 2, capture.get_height() / 2)
	if Vector3(actual.r - color.r, actual.g - color.g, actual.b - color.b).length() > 0.05:
		failures += 1
		push_error(label + ": " + str(actual))
