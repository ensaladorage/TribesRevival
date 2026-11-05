extends Node3D
## Godot entry point. Input produces semantic actions; nodes only read state.

const Session = preload("res://scripts/simulation/game_session.gd")
const WorldView = preload("res://scripts/view/world_view.gd")
var session := Session.new()
var world_view := WorldView.new()
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
	_create_overlay()
	_sync_view()

func _process(delta: float) -> void:
	camera.advance(delta, dragging, session.state.totem.position)
	if dragging:
		_queue_drag(get_viewport().get_mouse_position())
	session.advance(delta)
	_sync_view()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.adjust_zoom(-0.1)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.adjust_zoom(0.1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and session.state.phase == "playing" and not dragging and _hits_totem(event.position):
				dragging = true
				camera.recentering = false
				session.enqueue({"type": "pick-up-totem"})
				_queue_drag(event.position)
			elif not event.pressed and dragging:
				_end_drag()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_end_drag()
				session.enqueue({"type": "toggle-pause"})
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

func _hits_totem(screen_point: Vector2) -> bool:
	var origin := totem_view.to_local(camera.project_ray_origin(screen_point))
	var direction := totem_view.global_basis.inverse() * camera.project_ray_normal(screen_point)
	return totem_view.get_aabb().intersects_ray(origin, direction) != null

func _queue_drag(screen_point: Vector2) -> void:
	var point: Variant = camera.ground_point(screen_point)
	if point is Vector3:
		session.enqueue({"type": "drag-totem", "position": {"x": point.x, "y": point.z}})

func _end_drag() -> void:
	if not dragging:
		return
	_queue_drag(get_viewport().get_mouse_position())
	session.enqueue({"type": "drop-totem"})
	dragging = false
	camera.recentering = true

func _sync_view() -> void:
	world_view.sync(session.state, session.previous_positions, session.accumulator / Session.FIXED_DT)
	var totem: Dictionary = session.state.totem
	totem_view.position = Vector3(float(totem.position.x), 1.6 + (0.7 if totem.isCarried else 0.0), float(totem.position.y))
	pause_overlay.visible = session.state.phase == "paused"
	debug_label.text = "Tick %s · %s · velocidad ×%s\nTótem %.2f, %.2f" % [session.state.tick, session.state.phase, session.speed_multiplier, totem.position.x, totem.position.y]
	var amounts: Dictionary = session.state.inventory.amounts
	inventory_label.text = "Comida %s   Madera %s   Piedra %s   Brillo %s   Oro %s\nNivel %s · XP %s / %s" % [amounts.food, amounts.wood, amounts.stone, amounts.spark, amounts.gold, session.state.progression.level, session.state.progression.experience, session.state.progression.experienceToNextLevel]

func _create_overlay() -> void:
	var overlay := CanvasLayer.new()
	overlay.name = "Overlay"
	add_child(overlay)
	var hints := Label.new()
	hints.position = Vector2(20, 20)
	hints.text = "TRIBES REVIVAL\nArrastra el tótem · Rueda: zoom · Esc: pausa · 1/2/3: velocidad · Insert: debug"
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
	panel.position = Vector2(20, 135)
	panel.visible = false
	overlay.add_child(panel)
	debug_label = Label.new()
	panel.add_child(debug_label)
	var pause_button := Button.new()
	pause_button.text = "Pausa / Continuar"
	pause_button.pressed.connect(func():
		_end_drag()
		session.enqueue({"type": "toggle-pause"}))
	panel.add_child(pause_button)
	for multiplier in [1, 2, 3]:
		var button := Button.new()
		button.text = "Velocidad ×%s" % multiplier
		button.pressed.connect(func(): session.speed_multiplier = multiplier)
		panel.add_child(button)
