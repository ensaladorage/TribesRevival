extends SceneTree
## Signal/lifetime regression only: no rendered frames, game scene or simulation.

const Menus = preload("res://scripts/ui/game_menus.gd")
var menus: CanvasLayer
var failures: Array[String] = []
var events: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	menus = Menus.new()
	menus.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(menus)
	menus.main_requested.connect(menus.show_main)
	menus.resume_requested.connect(menus.show_game)
	menus.load_requested.connect(func(slot: int):
		events.append("load:%s" % slot)
		menus.show_game())
	menus.save_requested.connect(func(slot: int):
		events.append("save:%s" % slot)
		# Main's save handler also refreshes slots before displaying its result.
		menus.update_slots(menus._slots)
		menus.show_message("Guardada"))
	menus.delete_requested.connect(func(slot: int):
		events.append("delete:%s" % slot)
		menus.update_slots(_slots())
		menus.show_slots(menus.slot_mode, menus.origin, menus._slots))
	menus.update_slots(_slots())

	_press("Tutorial", "tutorial")
	_press("Volver", "main")
	_press("Cargar", "slots")
	_check(_button("Slot 1").disabled, "Empty load slot stays disabled")
	_press("Slot 2", "game", false)
	_check(events == ["load:2"], "Load signal keeps selected slot")

	menus.show_pause()
	_press("Guardar", "slots")
	_press("Slot 1", "message")
	_check(events.back() == "save:1", "Empty slot saves directly")
	_press("Volver", "slots")
	_press("Slot 2", "confirmation")
	_press("Cancelar", "slots")
	_press("Slot 2", "confirmation")
	_press("Guardar", "message")
	_check(events.back() == "save:2", "Overwrite saves selected slot")
	_press("Volver", "slots")
	_press("Eliminar slot 2", "confirmation")
	_press("Cancelar", "slots")
	_press("Eliminar slot 2", "confirmation")
	_press("Eliminar", "slots")
	_check(events.back() == "delete:2", "Delete emits selected slot")
	_press("Volver", "pause")

	menus.has_unsaved_changes = true
	_press("Cargar", "slots")
	_press("Slot 2", "confirmation")
	_press("Cancelar", "slots")
	_press("Slot 2", "confirmation")
	_press("Cargar", "game", false)
	_check(events.back() == "load:2", "Confirmed load keeps selected slot")
	menus.show_pause()
	_press("Menú principal", "confirmation")
	_press("Cancelar", "pause")
	_press("Menú principal", "confirmation")
	_press("Volver al menú", "main")
	menus.has_unsaved_changes = false
	menus.show_pause()
	_press("Menú principal", "main")
	menus.show_pause()
	_press("Volver", "game", false)

	root.remove_child(menus)
	menus.free()
	# Flush queued Controls in this isolated tree; no game instance exists.
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS menu callbacks: %s checks; isolated signals/lifetimes, no rendering or gameplay" % checks)
	quit(0 if failures.is_empty() else 1)

func _slots() -> Array:
	return [{"slot": 1, "status": "empty"}, {"slot": 2, "status": "valid", "save": {"metadata": {"level": 0, "minionCount": 2, "savedAt": "test"}}}, {"slot": 3, "status": "invalid", "reason": "test"}]

func _button(prefix: String) -> Button:
	for child in menus._content.get_children():
		if child is Button and child.text.begins_with(prefix):
			return child
	return null

func _press(prefix: String, expected_screen: String, rebuild: bool = true) -> void:
	var button := _button(prefix)
	_check(button != null, "Button exists: " + prefix)
	if button == null:
		return
	button.pressed.emit()
	_check(menus.screen == expected_screen, "Destination: " + prefix)
	if rebuild:
		_check(is_instance_valid(button) and button.is_queued_for_deletion() and button.get_parent() == null, "Emitting button detached and deferred: " + prefix)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
