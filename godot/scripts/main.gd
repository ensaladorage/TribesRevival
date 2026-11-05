extends Node3D
## Godot entry point. Input produces semantic actions; nodes only read state.

const Session = preload("res://scripts/simulation/game_session.gd")
const WorldView = preload("res://scripts/view/world_view.gd")
const HUD = preload("res://scenes/ui/HUD.tscn")
const Menus = preload("res://scenes/ui/Menus.tscn")
const Overlay = preload("res://scenes/ui/Overlay.tscn")
const Saves = preload("res://scripts/persistence/save_repository.gd")
@export var placement_scenes := {
	"gatherer": preload("res://scenes/placement/gatherer.tscn"),
	"axe": preload("res://scenes/placement/axe.tscn"),
	"bow": preload("res://scenes/placement/bow.tscn"),
	"sword": preload("res://scenes/placement/sword.tscn"),
	"hammer": preload("res://scenes/placement/hammer.tscn"),
	"mage": preload("res://scenes/placement/mage.tscn"),
	"campfire": preload("res://scenes/placement/campfire.tscn"),
	"shield": preload("res://scenes/placement/shield.tscn"),
}
var session := Session.new()
var world_view = preload("res://scenes/WorldView.tscn").instantiate()
var hud = HUD.instantiate()
var menus = Menus.instantiate()
var saves := Saves.new()
var saved_fingerprint := ""
var held_item := ""
var held_preview: Node3D
var drag_position: Variant = null
var drag_direction := Vector2(0, 1)
var direction_arrow: Node3D
var dragging := false
var debug_visible := false
var debug_label: Label
var pause_overlay: ColorRect
var inventory_label: Label
@onready var camera: Camera3D = $Camera3D
@onready var totem_view: MeshInstance3D = $Totem

func _ready() -> void:
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
	totem_view.position = Vector3(float(visual.x), 4.6 if dragging or totem.isCarried else 2.0, float(visual.y))
	totem_view.present(dragging or totem.isCarried)
	$TotemShadow.position = Vector3(visual.x, 0.04, visual.y)
	direction_arrow.position = Vector3(visual.x, 3.1, visual.y)
	direction_arrow.rotation.y = atan2(drag_direction.x, drag_direction.y)
	direction_arrow.visible = dragging or totem.isCarried
	pause_overlay.visible = false
	debug_label.text = "Tick %s · %s · velocidad ×%s\nTótem %.2f, %.2f" % [session.state.tick, session.state.phase, session.speed_multiplier, totem.position.x, totem.position.y]
	inventory_label.text = "Nivel %s · XP %s / %s · Puntos %s" % [session.state.progression.level, session.state.progression.experience, session.state.progression.experienceToNextLevel, session.state.progression.technologyPoints]
	Input.set_default_cursor_shape(Input.CURSOR_DRAG if dragging or not held_item.is_empty() else Input.CURSOR_ARROW)

func _create_direction_arrow() -> void:
	direction_arrow = preload("res://scenes/world/DirectionArrow.tscn").instantiate()
	direction_arrow.visible = false
	add_child(direction_arrow)

func _begin_placement(item: String) -> void:
	if session.state.phase != "playing" or menus.screen != "game":
		return
	_end_drag()
	_cancel_placement()
	held_item = item
	held_preview = placement_scenes[item].instantiate()
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
	var overlay := Overlay.instantiate()
	add_child(overlay)
	inventory_label = overlay.get_node("Progression")
	pause_overlay = overlay.get_node("Pause")
	debug_label = overlay.get_node("Debug/Status")
	overlay.get_node("Debug/PauseButton").pressed.connect(_open_pause)
	for button in overlay.get_node("Debug").find_children("*", "Button", true, false):
		if button.has_meta("multiplier"):
			var multiplier: int = button.get_meta("multiplier")
			button.pressed.connect(func(): session.speed_multiplier = multiplier)
		elif button.has_meta("action"):
			var action: String = button.get_meta("action")
			button.pressed.connect(func(): session.enqueue({"type": action}))
	for slider in overlay.get_node("Debug").find_children("*", "HSlider", true, false):
		var bound: String = slider.get_meta("bound")
		slider.value = camera.zoom_min if bound == "min" else camera.zoom_max
		slider.value_changed.connect(func(value):
			if bound == "min":
				camera.zoom_min = clampf(value, 0.5, camera.zoom_max - 0.05)
			else:
				camera.zoom_max = clampf(value, camera.zoom_min + 0.05, 2.0)
			camera.adjust_zoom(0))
