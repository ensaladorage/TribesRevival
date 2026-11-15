extends SceneTree
## Native GUI dispatch at button edges, without launching gameplay.

var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var menus := preload("res://scenes/ui/Menus.tscn").instantiate()
	root.add_child(menus)
	await process_frame
	await process_frame
	for button: Button in menus._content.find_children("*", "Button", true, false):
		for connection in button.pressed.get_connections():
			button.pressed.disconnect(connection.callable)
		var clicks := [0]
		button.pressed.connect(func(): clicks[0] += 1)
		var rect := button.get_global_rect()
		var points := [
			rect.position + Vector2(1, 1),
			rect.position + Vector2(rect.size.x - 1, 1),
			rect.end - Vector2(1, 1),
			rect.position + Vector2(1, rect.size.y - 1),
			rect.position + Vector2(rect.size.x / 2, rect.size.y - 1),
		]
		for point: Vector2 in points:
			var motion := InputEventMouseMotion.new()
			motion.position = point
			root.push_input(motion, true)
			await process_frame
			checks += 1
			if root.gui_get_hovered_control() != button:
				failures.append("%s must hover at %s" % [button.name, point])
			var before: int = clicks[0]
			for pressed in [true, false]:
				var event := InputEventMouseButton.new()
				event.position = point
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = pressed
				root.push_input(event, true)
			checks += 1
			if clicks[0] != before + 1:
				failures.append("%s must click at %s" % [button.name, point])
	menus.free()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS main menu hit areas: %s checks; native hover and clicks" % checks)
	quit(0 if failures.is_empty() else 1)
