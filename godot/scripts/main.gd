extends Node3D
## Godot entry point. Input produces semantic actions; nodes only read state.

const Session = preload("res://scripts/simulation/game_session.gd")
const WorldView = preload("res://scripts/view/world_view.gd")
const HUD = preload("res://scripts/ui/game_hud.gd")
const Menus = preload("res://scripts/ui/game_menus.gd")
const Saves = preload("res://scripts/persistence/save_repository.gd")
var session := Session.new()
var world_view := WorldView.new()
var hud := HUD.new()
var menus := Menus.new()
var saves := Saves.new()
var saved_fingerprint := ""
var held_item := ""
var held_preview: MeshInstance3D
var drag_position: Variant = null
var drag_direction := Vector2(0, 1)
var direction_arrow: MeshInstance3D
var dragging := false
var debug_visible := false
var debug_label: Label
var pause_overlay: ColorRect
var inventory_label: Label
@onready var camera: Camera3D = $Camera3D
@onready var totem_view: MeshInstance3D = $Totem

func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("26333b")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d3e2ef")
	environment.ambient_light_energy = 0.65
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	add_child(world_view)
	world_view.setup(session.state)
	_create_direction_arrow()
	_create_overlay()
	add_child(hud)
	hud.placement_requested.connect(_begin_placement)
	hud.action_requested.connect(func(action): session.enqueue(action))
	add_child(menus)
	menus.new_game_requested.connect(_new_game)
	menus.resume_requested.connect(_resume_game)
	menus.main_requested.connect(_return_to_main)
	menus.save_requested.connect(_save_slot)
	menus.load_requested.connect(_load_slot)
	menus.delete_requested.connect(_delete_slot)
	menus.update_slots(saves.list_slots())
	saved_fingerprint = Saves.fingerprint(session.state)
	_sync_view()

func _process(delta: float) -> void:
	if menus.screen == "game":
		camera.advance(delta, dragging, session.state.totem.position)
		if dragging:
			_queue_drag(get_viewport().get_mouse_position())
		if not held_item.is_empty():
			_update_held_preview()
		session.advance(delta)
		if session.state.phase == "defeat":
			_cancel_placement()
			_end_drag()
			session.flush_actions()
			menus.show_defeat()
	else:
		session.accumulator = 0.0
	_sync_view()

func _input(event: InputEvent) -> void:
	# Receive release even over a Control, matching pointer capture in Babylon.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if not held_item.is_empty():
			_finish_placement()
			# The source Button must also receive release to clear button_down.
			# These HUD buttons have no release action; placement finishes above.
		elif dragging:
			_end_drag()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if menus.screen != "game":
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			menus.handle_escape()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.adjust_zoom(-0.1)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.adjust_zoom(0.1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and session.state.phase == "playing" and not dragging and _hits_totem(event.position):
				dragging = true
				drag_position = session.state.totem.position.duplicate()
				drag_direction = Vector2(0, 1)
				camera.recentering = false
				session.enqueue({"type": "pick-up-totem"})
				_queue_drag(event.position)
			elif not event.pressed and dragging:
				_end_drag()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_open_pause()
			KEY_1, KEY_2, KEY_3:
				session.speed_multiplier = event.keycode - KEY_0
			KEY_PLUS, KEY_EQUAL, KEY_KP_ADD:
				camera.adjust_zoom(-0.1)
			KEY_MINUS, KEY_KP_SUBTRACT:
				camera.adjust_zoom(0.1)
			KEY_INSERT, KEY_KP_0:
				debug_visible = not debug_visible
				$Overlay/Debug.visible = debug_visible
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		_end_drag()
		_cancel_placement()

func _hits_totem(screen_point: Vector2) -> bool:
	var origin := totem_view.to_local(camera.project_ray_origin(screen_point))
	var direction := totem_view.global_basis.inverse() * camera.project_ray_normal(screen_point)
	return totem_view.get_aabb().intersects_ray(origin, direction) != null

func _queue_drag(screen_point: Vector2) -> void:
	var point: Variant = camera.ground_point(screen_point)
	if point is Vector3:
		var position: Dictionary = Session.State.clamp_position({"x": point.x, "y": point.z})
		if drag_position != null:
			var dx: float = position.x - drag_position.x
			var dy: float = position.y - drag_position.y
			var distance := sqrt(dx * dx + dy * dy)
			if distance <= 0.001:
				return
			drag_direction = Vector2(dx / distance, dy / distance)
		drag_position = position
		session.enqueue({"type": "drag-totem", "position": position})

func _end_drag() -> void:
	if not dragging:
		return
	_queue_drag(get_viewport().get_mouse_position())
	session.enqueue({"type": "drop-totem"})
	dragging = false
	camera.recentering = true

func _sync_view() -> void:
	hud.visible = menus.screen == "game"
	$Overlay.visible = menus.screen == "game"
	hud.update_state(session.state)
	world_view.sync(session.state, session.previous_positions, session.accumulator / Session.FIXED_DT)
	var totem: Dictionary = session.state.totem
	var visual: Dictionary = drag_position if (dragging or totem.isCarried) and drag_position != null else totem.position
	totem_view.position = Vector3(float(visual.x), 1.6 + (0.7 if dragging or totem.isCarried else 0.0), float(visual.y))
	direction_arrow.position = Vector3(visual.x, 3.1, visual.y)
	direction_arrow.rotation.y = atan2(drag_direction.x, drag_direction.y)
	direction_arrow.visible = dragging or totem.isCarried
	pause_overlay.visible = false
	debug_label.text = "Tick %s · %s · velocidad ×%s\nTótem %.2f, %.2f" % [session.state.tick, session.state.phase, session.speed_multiplier, totem.position.x, totem.position.y]
	inventory_label.text = "Nivel %s · XP %s / %s · Puntos %s" % [session.state.progression.level, session.state.progression.experience, session.state.progression.experienceToNextLevel, session.state.progression.technologyPoints]
	Input.set_default_cursor_shape(Input.CURSOR_DRAG if dragging or not held_item.is_empty() else Input.CURSOR_ARROW)

func _create_direction_arrow() -> void:
	direction_arrow = MeshInstance3D.new()
	var shape := ImmediateMesh.new()
	shape.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for point in [Vector3(0, 0, 2.8), Vector3(-0.65, 0, 1.9), Vector3(-0.2, 0, 2.05), Vector3(-0.2, 0, 0), Vector3(0.2, 0, 0), Vector3(0.2, 0, 2.05), Vector3(0.65, 0, 1.9), Vector3(0, 0, 2.8)]:
		shape.surface_add_vertex(point)
	shape.surface_end()
	direction_arrow.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f1d27a")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	direction_arrow.material_override = material
	direction_arrow.visible = false
	add_child(direction_arrow)

func _begin_placement(item: String) -> void:
	if session.state.phase != "playing" or menus.screen != "game":
		return
	_end_drag()
	_cancel_placement()
	held_item = item
	held_preview = MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = Vector3(0.8, 1.0, 0.8) * 1.25
	held_preview.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f2cb72")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	held_preview.material_override = material
	add_child(held_preview)
	_update_held_preview()

func _update_held_preview() -> void:
	var point: Variant = camera.ground_point(get_viewport().get_mouse_position())
	if point is Vector3:
		# Preview follows the raw cursor. Recruitment projection happens on release.
		held_preview.position = point + Vector3(0, 1.2, 0)

func _finish_placement() -> void:
	if get_viewport().gui_get_hovered_control() == null and session.state.phase == "playing":
		var screen_point := get_viewport().get_mouse_position()
		var point: Variant = camera.ground_point(screen_point)
		if held_item in ["gatherer", "campfire"] and point is Vector3:
			session.enqueue({"type": "recruit-gatherer" if held_item == "gatherer" else "place-campfire", "position": {"x": point.x, "y": point.z}})
		else:
			var unit_id: String = world_view.pick_unit(camera, screen_point, session.state.units)
			if not unit_id.is_empty():
				session.enqueue({"type": "equip-shield", "unitId": unit_id} if held_item == "shield" else {"type": "transform-unit", "item": held_item, "unitId": unit_id})
	_cancel_placement()

func _cancel_placement() -> void:
	held_item = ""
	if is_instance_valid(held_preview):
		held_preview.free()
	held_preview = null

func _new_game() -> void:
	_replace_state(Session.State.create_initial())
	menus.show_game()

func _replace_state(state: Dictionary) -> void:
	_cancel_placement()
	dragging = false
	drag_position = null
	session.replace_state(state)
	saved_fingerprint = Saves.fingerprint(session.state)
	world_view.setup(session.state)
	camera.focus = Vector3(state.totem.position.x, 0, state.totem.position.y)
	camera.recentering = false
	camera.zoom_min = 0.5
	camera.zoom_max = 1.0
	camera.zoom = 0.5
	camera.apply_transform()
	debug_visible = false
	$Overlay/Debug.hide()
	hud.reset_panels()
	_sync_view()

func _open_pause() -> void:
	if menus.screen != "game":
		return
	_cancel_placement()
	_end_drag()
	session.flush_actions()
	if session.state.phase == "playing":
		Session.Commands.apply(session.state, {"type": "toggle-pause"})
	menus.has_unsaved_changes = Saves.fingerprint(session.state) != saved_fingerprint
	menus.update_slots(saves.list_slots())
	menus.show_pause()

func _resume_game() -> void:
	if session.state.phase == "paused":
		Session.Commands.apply(session.state, {"type": "toggle-pause"})
	menus.show_game()

func _return_to_main() -> void:
	_cancel_placement()
	_end_drag()
	session.flush_actions()
	menus.update_slots(saves.list_slots())
	menus.show_main()

func _save_slot(slot: int) -> void:
	var result := saves.save_slot(slot, session.state)
	if result.ok:
		saved_fingerprint = Saves.fingerprint(session.state)
		menus.has_unsaved_changes = false
	menus.update_slots(saves.list_slots())
	menus.show_message("Partida guardada." if result.ok else result.error)

func _load_slot(slot: int) -> void:
	var result := saves.read_slot(slot)
	if result.status != "valid":
		menus.show_message("No se pudo cargar la partida.")
		return
	_replace_state(result.save.gameState)
	menus.show_game()

func _delete_slot(slot: int) -> void:
	var error := saves.delete_slot(slot)
	menus.update_slots(saves.list_slots())
	if error == OK:
		menus.show_slots(menus.slot_mode, menus.origin, saves.list_slots())
	else:
		menus.show_message("No se pudo eliminar la partida.")

func _create_overlay() -> void:
	var overlay := CanvasLayer.new()
	overlay.name = "Overlay"
	add_child(overlay)
	var hints := Label.new()
	hints.position = Vector2(20, 20)
	hints.text = "TRIBES REVIVAL"
	hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(hints)
	inventory_label = Label.new()
	inventory_label.position = Vector2(20, 65)
	inventory_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(inventory_label)
	pause_overlay = ColorRect.new()
	pause_overlay.color = Color(0.05, 0.08, 0.12, 0.6)
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(pause_overlay)
	var paused_text := Label.new()
	paused_text.text = "Pausa · Esc para continuar"
	paused_text.position = Vector2(500, 320)
	paused_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_overlay.add_child(paused_text)
	var panel := VBoxContainer.new()
	panel.name = "Debug"
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-260, 120)
	panel.visible = false
	overlay.add_child(panel)
	debug_label = Label.new()
	panel.add_child(debug_label)
	var pause_button := Button.new()
	pause_button.text = "Pausa / Continuar"
	pause_button.pressed.connect(_open_pause)
	panel.add_child(pause_button)
	for multiplier in [1, 2, 3]:
		var button := Button.new()
		button.text = "Velocidad ×%s" % multiplier
		button.pressed.connect(func(): session.speed_multiplier = multiplier)
		panel.add_child(button)
	for entry in [["Dañar un minion", "debug-damage-one-minion"], ["Subir nivel", "debug-level-up"], ["Añadir recursos", "debug-add-all-resources"]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(func(): session.enqueue({"type": entry[1]}))
		panel.add_child(button)
	for bound in ["min", "max"]:
		var label := Label.new()
		label.text = "Zoom " + bound
		panel.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0.5
		slider.max_value = 2.0
		slider.step = 0.05
		slider.value = camera.zoom_min if bound == "min" else camera.zoom_max
		slider.value_changed.connect(func(value):
			if bound == "min":
				camera.zoom_min = clampf(value, 0.5, camera.zoom_max - 0.05)
			else:
				camera.zoom_max = clampf(value, camera.zoom_min + 0.05, 2.0)
			camera.adjust_zoom(0))
		panel.add_child(slider)
