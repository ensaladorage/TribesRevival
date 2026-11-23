extends SceneTree
## Exercise the review scene's screen-to-ground drag path and capture the crossing.
const View = preload("res://scripts/view/terrain_projection.gd")
const T = View.T
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/world/LandscapeReview.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	var state: Dictionary = game.session.state
	var home: Dictionary = state.totem.position.duplicate()
	var lower := T.cell(home)
	var upper := T.cell(state.biomes[2].region)
	var grid := T.graph(state.terrain)
	var filename := "res://reports/landscape/crossing.png"
	DirAccess.make_dir_recursive_absolute(filename.get_base_dir())
	var captured := false
	for destination in [upper,lower]:
		var start := T.cell(state.totem.position)
		var route := grid.get_id_path(start.y*T.SIZE+start.x,destination.y*T.SIZE+destination.x)
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = game.camera.unproject_position(game.totem_view.global_position)
		game._unhandled_input(press)
		if not game.dragging:
			push_error("Could not pick up the totem")
			quit(1)
			return
		for id in route:
			var cell := Vector2i(id%T.SIZE,floori(float(id)/T.SIZE))
			var point := View.world(T.center(cell),state.terrain)
			game.camera.focus = point
			game.camera.apply_transform()
			game._queue_drag(game.camera.unproject_position(point))
			for tick in 6: game.session.advance(game.Session.FIXED_DT)
			game._sync_view()
			if not captured and T.ramp(T.code(state.terrain,cell)):
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(filename)
				captured = true
		# Use the logical drop already used by the release handler. The OS cursor
		# stays untouched during this offscreen geometry check.
		game.session.enqueue({"type":"drop-totem"})
		game.dragging = false
		var arrived := false
		for tick in 1600:
			game.session.advance(game.Session.FIXED_DT)
			if not state.totem.moving and state.inventory.amounts.stone > 0 and state.units.all(func(u): return T.fraction(state.terrain,u.position) == (1.0 if destination == upper else 0.0)):
				arrived = true
				break
		if not arrived:
			push_error("Incomplete review trip at "+str(destination))
			quit(1)
			return
		game._sync_view()
	print("PASS review: projected drag, eight units, stone delivery and descent")
	game.free()
	quit()
