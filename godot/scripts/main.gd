extends Node3D
## Godot entry point. Input produces semantic actions; nodes only read state.

const Session = preload("res://scripts/simulation/game_session.gd")
const Numbers = preload("res://scripts/ui/player_numbers.gd")
const WorldView = preload("res://scripts/view/world_view.gd")
const HUD = preload("res://scenes/ui/HUD.tscn")
const Menus = preload("res://scenes/ui/Menus.tscn")
const Overlay = preload("res://scenes/ui/Overlay.tscn")
const Saves = preload("res://scripts/persistence/save_repository.gd")
const TOTEM_REST_HEIGHT := 2.0
const TOTEM_CARRIED_HEIGHT := 4.6
@export_group("Cursors")
@export var arrow_cursor: Texture2D = preload("res://assets/ui/cursors/default.png")
@export var interact_cursor: Texture2D = preload("res://assets/ui/cursors/interact.png")
@export var grab_cursor: Texture2D = preload("res://assets/ui/cursors/grab.png")
@export var arrow_hotspot := Vector2(22, 18)
@export var interact_hotspot := Vector2(22, 18)
@export var grab_hotspot := Vector2(32, 32)
@export_group("")
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
var dragging := false
var dragged_minion_id := ""
var minion_drag_position: Variant = null
var debug_visible := false
var debug_label: Label
var pause_overlay: ColorRect
var _cursor_shape := -1
var carry_cursor: CanvasLayer
var _carry_cursor_mouse_mode := Input.MOUSE_MODE_VISIBLE
@onready var camera: Camera3D = $Camera3D
@onready var totem_view: Node3D = $Totem

func _ready() -> void:
	carry_cursor = preload("res://scenes/ui/CarryCursor.tscn").instantiate()
	add_child(carry_cursor)
	add_child(world_view)
	world_view.setup(session.state)
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
		if dragged_minion_id.is_empty():
			camera.advance(delta, dragging, session.state.totem.position)
		if dragging:
			_queue_drag(get_viewport().get_mouse_position())
		if not dragged_minion_id.is_empty():
			_queue_minion_drag(get_viewport().get_mouse_position())
		if not held_item.is_empty():
			_update_held_preview()
		session.advance(delta)
		if session.state.phase == "defeat":
			_cancel_placement()
			_end_drag()
			_end_minion_drag()
			session.flush_actions()
			menus.show_defeat()
	else:
		session.accumulator = 0.0
	_sync_view()
	world_view.update_occlusion(camera, delta)

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
		elif not dragged_minion_id.is_empty():
			_queue_minion_drag(event.position)
			_end_minion_drag()
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
			if event.pressed and session.state.phase == "playing" and not dragging and dragged_minion_id.is_empty() and held_item.is_empty():
				if _hits_totem(event.position):
					dragging = true
					drag_position = session.state.totem.position.duplicate()
					camera.recentering = false
					session.enqueue({"type": "pick-up-totem"})
					_queue_drag(event.position)
				else:
					_begin_minion_drag(event.position)
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
		_update_carry_cursor(false)
		_end_drag()
		_end_minion_drag()
		session.flush_actions()
		_cancel_placement()

func _hits_totem(screen_point: Vector2) -> bool:
	var origin := totem_view.to_local(camera.project_ray_origin(screen_point))
	var direction := totem_view.global_basis.inverse() * camera.project_ray_normal(screen_point)
	return AABB(Vector3(-1.2, -2.0, -0.8), Vector3(2.4, 4.0, 1.6)).intersects_ray(origin, direction) != null

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
		drag_position = position
		session.enqueue({"type": "drag-totem", "position": position})

func _end_drag() -> void:
	if not dragging:
		return
	_queue_drag(get_viewport().get_mouse_position())
	session.enqueue({"type": "drop-totem"})
	dragging = false
	camera.recentering = true

func _begin_minion_drag(screen_point: Vector2) -> void:
	var unit_id: String = world_view.pick_unit(camera, screen_point, session.state.units)
	if unit_id.is_empty():
		return
	dragged_minion_id = unit_id
	minion_drag_position = Session.Movement.find_entity(session.state.units, unit_id).position.duplicate()
	camera.recentering = false
	session.enqueue({"type": "pick-up-minion", "unitId": unit_id})
	_queue_minion_drag(screen_point)

func _queue_minion_drag(screen_point: Vector2) -> void:
	# Keep the last map position when crossing HUD or leaving the viewport.
	if get_viewport().gui_get_hovered_control() != null or not get_viewport().get_visible_rect().has_point(screen_point):
		return
	var point: Variant = camera.ground_point(screen_point)
	if point is Vector3:
		minion_drag_position = Session.State.clamp_position({"x": point.x, "y": point.z})
		session.enqueue({"type": "drag-minion", "unitId": dragged_minion_id, "position": minion_drag_position})

func _end_minion_drag() -> void:
	if dragged_minion_id.is_empty():
		return
	session.enqueue({"type": "drop-minion", "unitId": dragged_minion_id})
	dragged_minion_id = ""
	minion_drag_position = null

func _sync_view() -> void:
	hud.visible = menus.screen == "game"
	$Overlay.visible = menus.screen == "game"
	hud.update_state(session.state)
	world_view.carried_preview = {"unitId": dragged_minion_id, "position": minion_drag_position}
	world_view.sync(session.state, session.previous_positions, session.accumulator / Session.FIXED_DT)
	var totem: Dictionary = session.state.totem
	var visual: Dictionary = drag_position if (dragging or totem.isCarried) and drag_position != null else totem.position
	totem_view.position = Vector3(float(visual.x), TOTEM_CARRIED_HEIGHT if dragging or totem.isCarried else TOTEM_REST_HEIGHT, float(visual.y))
	totem_view.present(dragging or totem.isCarried)
	$TotemShadow.position = Vector3(visual.x, 0.04, visual.y)
	pause_overlay.visible = false
	debug_label.text = "Tick %s · %s · velocidad ×%s\nTótem %s, %s" % [Numbers.integer(session.state.tick), session.state.phase, Numbers.integer(session.speed_multiplier), Numbers.integer(totem.position.x), Numbers.integer(totem.position.y)]
	_update_cursor()

func _cursor_for_point(screen_point: Vector2, over_ui: bool) -> int:
	if menus.screen != "game" or session.state.phase != "playing":
		return Input.CURSOR_ARROW
	if dragging or not dragged_minion_id.is_empty() or not held_item.is_empty():
		return Input.CURSOR_DRAG
	if over_ui:
		return Input.CURSOR_ARROW
	if _hits_totem(screen_point) or not world_view.pick_unit(camera, screen_point, session.state.units).is_empty():
		return Input.CURSOR_POINTING_HAND
	return Input.CURSOR_ARROW

func _update_cursor() -> void:
	var shape := _cursor_for_point(get_viewport().get_mouse_position(), get_viewport().gui_get_hovered_control() != null)
	_update_carry_cursor(shape == Input.CURSOR_DRAG and (dragging or not dragged_minion_id.is_empty()))
	if shape == _cursor_shape:
		return
	_cursor_shape = shape
	var texture := arrow_cursor
	var hotspot := arrow_hotspot
	if shape == Input.CURSOR_DRAG:
		texture = grab_cursor
		hotspot = grab_hotspot
	elif shape == Input.CURSOR_POINTING_HAND:
		texture = interact_cursor
		hotspot = interact_hotspot
	# Controls use ARROW too, so carrying stays visible while crossing the HUD.
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, hotspot)
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_POINTING_HAND, hotspot)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _update_carry_cursor(active: bool) -> void:
	var hand: TextureRect = carry_cursor.get_node("Hand")
	if active:
		if not hand.visible:
			_carry_cursor_mouse_mode = Input.mouse_mode
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		hand.texture = grab_cursor
		hand.position = _carry_cursor_position() - grab_hotspot
	elif hand.visible:
		Input.mouse_mode = _carry_cursor_mouse_mode
	hand.visible = active

func _carry_cursor_position() -> Vector2:
	if dragging:
		var resting := totem_view.global_position - Vector3.UP * (TOTEM_CARRIED_HEIGHT - TOTEM_REST_HEIGHT)
		return get_viewport().get_mouse_position() + camera.unproject_position(totem_view.global_position) - camera.unproject_position(resting)
	return get_viewport().get_mouse_position() + world_view.carried_screen_offset(camera, dragged_minion_id)

func _exit_tree() -> void:
	if is_instance_valid(carry_cursor) and carry_cursor.get_node("Hand").visible:
		Input.mouse_mode = _carry_cursor_mouse_mode

func _begin_placement(item: String) -> void:
	if session.state.phase != "playing" or menus.screen != "game":
		return
	_end_drag()
	_end_minion_drag()
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
	dragged_minion_id = ""
	minion_drag_position = null
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
	_end_minion_drag()
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
	_end_minion_drag()
	session.flush_actions()
	menus.update_slots(saves.list_slots())
	menus.show_main()

func _save_slot(slot: int) -> void:
	_end_minion_drag()
	session.flush_actions()
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
