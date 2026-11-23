extends SceneTree
## Native dispatch and scene integration; no manual/visual QA claim.

const MainScene = preload("res://scenes/main.tscn")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)

func _mouse(point: Vector2, pressed: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	root.push_input(event, true)

func _run() -> void:
	var main := MainScene.instantiate()
	main.set_process(false)
	root.add_child(main)
	var prohibited_image: Image = main.prohibited_cursor.get_image()
	_check(prohibited_image.get_size() == Vector2i(64, 64) and not prohibited_image.has_mipmaps(), "Prohibited artwork must retain its original dimensions without mipmaps")
	main._new_game()
	main.session.state.resources = []
	main.session.state.barbarians = []
	main.session.state.animals = []
	var unit: Dictionary = main.session.state.units[0]
	unit.position = {"x": 85.0, "y": 80.0}
	main.session.flush_actions()
	main._sync_view()
	await process_frame
	var screen: Vector2 = main.camera.unproject_position(main.TerrainView.world(unit.position,main.session.state.terrain) + Vector3.UP * 0.8)
	_check(main._cursor_for_point(screen, false) == Input.CURSOR_POINTING_HAND, "Hovering a minion must show interact")
	_check(main._cursor_for_point(screen, true) == Input.CURSOR_ARROW, "HUD must use arrow when empty handed")
	var idle_task: Dictionary = unit.task.duplicate(true)
	unit.task.kind = "combat"
	_check_blocked_cursor(main, screen)
	_mouse(screen, true)
	main.session.flush_actions()
	_check(main.dragged_minion_id.is_empty() and not unit.get("isCarried", false), "Combat click must not start a drag")
	_mouse(screen, false)
	unit.task = idle_task
	unit.pickupLockTicks = 1
	_check_blocked_cursor(main, screen)
	unit.erase("pickupLockTicks")
	main._present_cursor(main._cursor_for_point(screen, false), screen)
	_check(not main.carry_cursor.get_node("Hand").visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Eligible minion must restore native cursor")
	_mouse(screen, true)
	main.session.flush_actions()
	_check(main.dragged_minion_id == unit.id and unit.get("isCarried", false), "Left press must lift the selected minion")
	_check(main._cursor_for_point(screen, true) == Input.CURSOR_DRAG, "Carrying over HUD must keep grab")
	var focus: Vector3 = main.camera.focus
	var destination: Vector2 = main.camera.unproject_position(main.TerrainView.world({"x":88,"y":84},main.session.state.terrain))
	main._queue_minion_drag(destination)
	main.session.flush_actions()
	main._sync_view()
	_check(main.camera.focus == focus and not main.camera.recentering, "Minion drag must leave camera fixed")
	var view: Node3D = main.world_view._views[unit.id]
	_check(view.get_node("Body").position.y > 2, "Scene must present raised body")
	_check_carry_cursor(main, view.carried_height)
	main._landing_valid = false
	_check_blocked_cursor(main, screen)
	main._landing_valid = true
	var expected: Dictionary = unit.position.duplicate()
	_mouse(destination, false)
	_check(main.dragged_minion_id.is_empty() and unit.get("isCarried", false), "Release must remain queued until the next simulation step")
	_check(main._cursor_for_point(destination, false) == Input.CURSOR_ARROW, "Queued release must not flash the prohibited cursor")
	main.session.flush_actions()
	main._sync_view()
	_check(main.dragged_minion_id.is_empty() and not unit.get("isCarried", false), "Mouse release must drop the minion")
	_check(main.session.Movement.Geo.distance(unit.position, expected) < 0.001, "Release must use cursor position")
	_check(not view.has_node("CarryMarker"), "Dragged minion must have no ground marker")
	_check(not main.carry_cursor.get_node("Hand").visible and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Drop must restore native cursor")
	# Use a real Control that consumes input to verify release capture over UI.
	var blocker := Button.new()
	blocker.position = Vector2(4, 4)
	blocker.size = Vector2(120, 40)
	root.add_child(blocker)
	for interruption in ["hud", "focus", "pause"]:
		main._resume_game()
		main.session.flush_actions()
		main._sync_view()
		screen = main.camera.unproject_position(main.TerrainView.world(unit.position,main.session.state.terrain) + Vector3.UP * 0.8)
		_mouse(screen, true)
		main.session.flush_actions()
		_check(unit.get("isCarried", false), "Must lift before interruption: " + interruption)
		expected = unit.position.duplicate()
		if interruption == "hud":
			_mouse(Vector2(20, 20), false)
		elif interruption == "focus":
			main._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		else:
			main._open_pause()
		main.session.flush_actions()
		_check(not unit.get("isCarried", false) and main.dragged_minion_id.is_empty(), "Interruption must release: " + interruption)
		_check(main.session.Movement.Geo.distance(unit.position, expected) < 0.001, "Interruption must preserve last map point: " + interruption)
	blocker.free()
	main._resume_game()
	main._sync_view()
	var totem_screen: Vector2 = main.camera.unproject_position(main.totem_view.global_position)
	_check(main._cursor_for_point(totem_screen, false) == Input.CURSOR_POINTING_HAND, "Hovering the totem must show interact")
	_mouse(totem_screen, true)
	main.session.flush_actions()
	_check(main.dragging and main.session.state.totem.isCarried, "Existing totem pickup must still work")
	_check(main._cursor_for_point(totem_screen, false) == Input.CURSOR_DRAG, "Carrying totem must show grab")
	main._sync_view()
	_check_carry_cursor(main, main.TOTEM_CARRIED_HEIGHT - main.TOTEM_REST_HEIGHT)
	main._landing_valid = false
	_check_blocked_cursor(main, totem_screen)
	main._landing_valid = true
	_mouse(totem_screen, false)
	main.session.flush_actions()
	_check(not main.dragging and not main.session.state.totem.isCarried, "Existing totem release must still work")
	main.held_item = "gatherer"
	main._landing_valid = false
	_check_blocked_cursor(main, screen)
	var item_target: Vector2 = main.camera.unproject_position(main.TerrainView.world(unit.position, main.session.state.terrain) + Vector3.UP * 0.65)
	var empty_point := Vector2(100, 100)
	main.held_item = "shield"
	_check(main._cursor_for_point(empty_point, false) == Input.CURSOR_DRAG, "A held item without a recipient must keep the grab cursor")
	_check_blocked_cursor(main, item_target)
	main.held_item = "bow"
	var inventory: Dictionary = main.session.state.inventory.amounts.duplicate()
	for resource in main.session.state.inventory.amounts:
		main.session.state.inventory.amounts[resource] = 100
	_check(main._cursor_for_point(item_target, false) == Input.CURSOR_DRAG, "A compatible recipient must keep the grab cursor")
	main.session.state.inventory.amounts = inventory
	main.held_item = "gatherer"
	_check(main._cursor_for_point(screen, true) == Input.CURSOR_DRAG, "HUD placement must show grab")
	main.held_item = ""
	main._open_pause()
	_check(main._cursor_for_point(totem_screen, false) == Input.CURSOR_ARROW, "Pause menu must show arrow")
	main._resume_game()
	main._sync_view()
	var skull: Button = main.hud.sacrifice_target
	var skull_point := skull.get_global_rect().get_center()
	_check(not skull.visible, "Skull hidden with empty hand")
	main.session.state.units[1].role = "hunter"
	for count in [2, 1]:
		var carried: Dictionary = main.session.state.units[0]
		screen = main.camera.unproject_position(main.TerrainView.world(carried.position,main.session.state.terrain) + Vector3.UP * 0.8)
		main._begin_minion_drag(screen)
		main.session.flush_actions()
		main._sync_view()
		_check(skull.visible and skull.disabled == (count == 1), "Skull availability reflects living tribe")
		var food := int(main.session.state.inventory.amounts.food)
		var body: Rect2 = main.world_view.carried_body_rect(main.camera, carried.id, carried.position)
		var feet: Vector2 = main.camera.unproject_position(main.TerrainView.world(carried.position,main.session.state.terrain))
		var release_point := skull_point - (body.get_center() - feet)
		if count == 1:
			_check_blocked_cursor(main, release_point)
		_mouse(release_point, false)
		main.session.flush_actions()
		main._sync_view()
		if count == 1:
			_check(main.session.Movement.Idle.within_range(carried.position, main.session.Movement.area(main.session.state)), "Rejected sacrifice must land inside command range")
		_check(main.session.state.units.size() == 1 and not skull.visible, "Release resolves drag and protects last unit")
		_check(main.session.state.inventory.amounts.food == food + (1 if count == 2 else 0), "Reward only for successful sacrifice")
	main.free()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS minion drag input: %s checks; native dispatch and scene structure, no visual QA" % checks)
	quit(0 if failures.is_empty() else 1)

func _check_blocked_cursor(main: Node3D, screen: Vector2) -> void:
	main._present_cursor(main._cursor_for_point(screen, false), screen)
	var hand: TextureRect = main.carry_cursor.get_node("Hand")
	_check(hand.visible and hand.texture == main.prohibited_cursor and hand.modulate == Color.WHITE, "Blocked action must show the prohibited artwork at its original color")
	_check(hand.scale == Vector2(0.75, 0.75), "Prohibited cursor must display at 75 percent")
	var expected := screen
	if not main.dragged_minion_id.is_empty():
		expected += main.world_view.carried_screen_offset(main.camera, main.dragged_minion_id)
	_check((hand.position + main.prohibited_hotspot * 0.75).distance_to(expected) < 0.01, "Prohibited cursor must align with the lifted minion or the pointer")

func _check_carry_cursor(main: Node3D, height: float) -> void:
	var original_size: float = main.camera.size
	for zoom in [18.0, 36.0]:
		main.camera.size = zoom
		main._update_cursor()
		var mouse: Vector2 = main.get_viewport().get_mouse_position()
		var ground: Vector3 = main.camera.ground_point(mouse)
		var expected: Vector2 = mouse + main.camera.unproject_position(ground + Vector3.UP * height) - main.camera.unproject_position(ground)
		var hand: TextureRect = main.carry_cursor.get_node("Hand")
		_check(hand.visible and hand.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Carry cursor must render without consuming input")
		_check((hand.position + main.grab_hotspot).distance_to(expected) < 0.01 and expected.y < mouse.y, "Cursor must match projected lift at zoom %s" % zoom)
	main.camera.size = original_size
	main._update_cursor()
