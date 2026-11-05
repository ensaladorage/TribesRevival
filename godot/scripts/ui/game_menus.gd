extends CanvasLayer
## Modal navigation and save confirmations; no simulation mutation here.

signal new_game_requested
signal resume_requested
signal main_requested
signal save_requested(slot: int)
signal load_requested(slot: int)
signal delete_requested(slot: int)

var screen := "main"
var origin := "main"
var slot_mode := "load"
var has_unsaved_changes := false
var _root: Control
var _background: ColorRect
var _content: VBoxContainer
var _slots: Array = []

func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_background = ColorRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 420
	var style := StyleBoxFlat.new()
	style.bg_color = Color("233037")
	style.set_content_margin_all(24)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	panel.add_child(_content)
	show_main()

func _clear(title: String, opaque: bool) -> void:
	_root.show()
	_background.color = Color(0.06, 0.09, 0.12, 1.0 if opaque else 0.65)
	for child in _content.get_children():
		# Navigation can run inside this child's pressed signal. Detach it now,
		# but release it after Godot finishes dispatching the signal.
		_content.remove_child(child)
		child.queue_free()
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(label)

func _button(text: String, callback: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 40
	button.disabled = disabled
	button.pressed.connect(callback)
	_content.add_child(button)
	return button

func _text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 400
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(label)

func show_main() -> void:
	screen = "main"
	origin = "main"
	_clear("Tribes Revival", true)
	_button("Jugar", func(): new_game_requested.emit())
	_button("Tutorial", show_tutorial)
	_button("Cargar", func(): show_slots("load", "main", _slots))
	_button("Salir", func(): get_tree().quit())

func show_tutorial() -> void:
	screen = "tutorial"
	_clear("Cómo jugar", true)
	_text("Sobrevive y progresa guiando a tu tribu con el tótem.\n\nArrástralo para explorar y reagrupar a los minions. Haz una parada junto a los recursos para que trabajen solos. El terreno vacío no mueve el tótem.")
	_text("Recolector: comida. Leñador: madera y combate. Cazador: conejos y combate a distancia. Guardián: cuerpo a cuerpo. Artesana: piedra y Brillo. Mago: clase legendaria.")
	_text("Arrastra los botones laterales al mapa o el equipo sobre un Recolector. Investiga tecnologías y mejora herramientas. Las hogueras consumen comida para curar. Si muere toda la tribu, la partida termina.")
	_text("Rueda / + / −: zoom · Esc: pausa · 1/2/3: velocidad · Insert: debug")
	_button("Jugar", func(): new_game_requested.emit())
	_button("Volver", show_main)

func show_pause() -> void:
	screen = "pause"
	origin = "pause"
	_clear("Pausa", false)
	_button("Volver", func(): resume_requested.emit())
	_button("Guardar", func(): show_slots("save", "pause", _slots))
	_button("Cargar", func(): show_slots("load", "pause", _slots))
	_button("Menú principal", _confirm_main)

func _confirm_main() -> void:
	if not has_unsaved_changes:
		main_requested.emit()
		return
	screen = "confirmation"
	_clear("Volver al menú principal", false)
	_text("Los cambios sin guardar se perderán.")
	_button("Volver al menú", func(): main_requested.emit())
	_button("Cancelar", show_pause)

func show_game() -> void:
	screen = "game"
	_root.hide()

func show_defeat() -> void:
	screen = "defeat"
	_clear("Tu tribu ha muerto", false)
	_button("Reiniciar", func(): new_game_requested.emit())
	_button("Menú principal", func(): main_requested.emit())

func update_slots(slots: Array) -> void:
	_slots = slots
	if screen == "slots":
		show_slots(slot_mode, origin, slots)

func show_slots(mode: String, from_screen: String, slots: Array) -> void:
	screen = "slots"
	origin = from_screen
	slot_mode = mode
	_slots = slots
	_clear("Guardar partida" if mode == "save" else "Cargar partida", origin == "main")
	for slot in slots:
		var text := "Slot %s · Vacío" % slot.slot
		if slot.status == "valid":
			text = "Slot %s · Nivel %s · %s minions\n%s" % [slot.slot, slot.save.metadata.level, slot.save.metadata.minionCount, slot.save.metadata.savedAt]
		elif slot.status == "invalid":
			text = "Slot %s · No disponible (%s)" % [slot.slot, slot.reason]
		_button(text, func():
			if mode == "save":
				if slot.status == "empty":
					save_requested.emit(slot.slot)
				else:
					_confirm_save(slot.slot)
			else:
				_request_load(slot.slot), mode == "load" and slot.status != "valid")
		if slot.status != "empty":
			_button("Eliminar slot %s" % slot.slot, func(): _confirm_delete(slot.slot))
	_button("Volver", show_pause if origin == "pause" else show_main)

func _confirm_delete(slot: int) -> void:
	screen = "confirmation"
	_clear("Eliminar partida", origin == "main")
	_text("¿Eliminar el slot %s? Esta operación no se puede deshacer." % slot)
	_button("Eliminar", func(): delete_requested.emit(slot))
	_button("Cancelar", func(): show_slots(slot_mode, origin, _slots))

func _confirm_save(slot: int) -> void:
	screen = "confirmation"
	_clear("Reemplazar partida", false)
	_text("¿Reemplazar el guardado del slot %s?" % slot)
	_button("Guardar", func(): save_requested.emit(slot))
	_button("Cancelar", func(): show_slots(slot_mode, origin, _slots))

func _request_load(slot: int) -> void:
	if origin != "pause" or not has_unsaved_changes:
		load_requested.emit(slot)
		return
	screen = "confirmation"
	_clear("Cargar partida", false)
	_text("Los cambios sin guardar se perderán.")
	_button("Cargar", func(): load_requested.emit(slot))
	_button("Cancelar", func(): show_slots(slot_mode, origin, _slots))

func show_message(message: String) -> void:
	screen = "message"
	_clear("Tribes Revival", origin == "main")
	_text(message)
	_button("Volver", func(): show_slots(slot_mode, origin, _slots))

func handle_escape() -> void:
	match screen:
		"pause": resume_requested.emit()
		"tutorial": show_main()
		"slots", "confirmation", "message":
			if origin == "pause":
				show_pause()
			else:
				show_main()
