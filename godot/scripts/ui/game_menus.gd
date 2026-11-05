extends CanvasLayer
## Scene-backed modal navigation; save data only configures dynamic slot rows.

signal new_game_requested
signal resume_requested
signal main_requested
signal save_requested(slot: int)
signal load_requested(slot: int)
signal delete_requested(slot: int)

@export var page_scenes := {
	"main": preload("res://scenes/ui/MainMenu.tscn"),
	"tutorial": preload("res://scenes/ui/TutorialMenu.tscn"),
	"pause": preload("res://scenes/ui/PauseMenu.tscn"),
	"defeat": preload("res://scenes/ui/DefeatMenu.tscn"),
	"slots": preload("res://scenes/ui/SlotsMenu.tscn"),
	"confirmation": preload("res://scenes/ui/ConfirmationMenu.tscn"),
	"message": preload("res://scenes/ui/FeedbackMenu.tscn"),
}
const SLOT_ROW = preload("res://scenes/ui/SlotRow.tscn")
@export var opaque_background := Color("777777")
@export var overlay_background := Color(0.058824, 0.047059, 0.078431, 0.72)
var screen := "main"
var origin := "main"
var slot_mode := "load"
var has_unsaved_changes := false
@export_group("Scene references")
@export var layout_root: Control
@export var background: ColorRect
@export var page_host: Control
var _content: Control
var _slots: Array = []
var _confirmation_return_screen := "pause"

func _ready() -> void:
	show_main()

func _clear(title: String, opaque: bool) -> void:
	layout_root.show()
	background.color = opaque_background if opaque else overlay_background
	if is_instance_valid(_content):
		# An emitting button may belong to this page; detach, then free deferred.
		_content.get_parent().remove_child(_content)
		_content.queue_free()
	_content = page_scenes[screen].instantiate()
	page_host.add_child(_content)
	_content.find_child("Title", true, false).text = title
	page_host.theme_type_variation = StringName(_content.get_meta("panel_style", "MenuPanel"))

func _connect_button(node_name: String, callback: Callable) -> void:
	_content.find_child(node_name, true, false).pressed.connect(callback)

func show_main() -> void:
	screen = "main"
	origin = "main"
	_clear("Tribes Revival", true)
	_connect_button("Play", func(): new_game_requested.emit())
	_connect_button("Tutorial", show_tutorial)
	_connect_button("Load", func(): show_slots("load", "main", _slots))
	_connect_button("Quit", func(): get_tree().quit())

func show_tutorial() -> void:
	screen = "tutorial"
	_clear("Cómo jugar", true)
	_connect_button("Play", func(): new_game_requested.emit())
	_connect_button("Back", show_main)

func show_pause() -> void:
	screen = "pause"
	origin = "pause"
	_clear("Pausa", false)
	_connect_button("Resume", func(): resume_requested.emit())
	_connect_button("Save", func(): show_slots("save", "pause", _slots))
	_connect_button("Load", func(): show_slots("load", "pause", _slots))
	_connect_button("Main", _confirm_main)

func _confirmation(title: String, message: String, text: String, callback: Callable, cancel: Callable, opaque: bool) -> void:
	screen = "confirmation"
	_clear(title, opaque)
	_content.find_child("Message").text = message
	_content.find_child("Confirm").text = text
	_connect_button("Confirm", callback)
	_connect_button("Cancel", cancel)

func _confirm_main() -> void:
	if not has_unsaved_changes:
		main_requested.emit()
		return
	_confirmation_return_screen = "pause"
	_confirmation("Volver al menú principal", "Los cambios sin guardar se perderán.", "Volver al menú", func(): main_requested.emit(), show_pause, false)

func show_game() -> void:
	screen = "game"
	layout_root.hide()

func show_defeat() -> void:
	screen = "defeat"
	_clear("Tu tribu ha muerto", false)
	_connect_button("Restart", func(): new_game_requested.emit())
	_connect_button("Main", func(): main_requested.emit())

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
		var row = SLOT_ROW.instantiate()
		_content.find_child("Rows").add_child(row)
		var button: Button = row.get_node("Select")
		button.text = "Slot %s · Vacío" % slot.slot
		if slot.status == "valid":
			button.text = "Slot %s · Nivel %s · %s minions\n%s" % [slot.slot, slot.save.metadata.level, slot.save.metadata.minionCount, slot.save.metadata.savedAt]
		elif slot.status == "invalid":
			button.text = "Slot %s · No disponible (%s)" % [slot.slot, slot.reason]
		button.disabled = mode == "load" and slot.status != "valid"
		button.pressed.connect(func():
			if mode == "save":
				if slot.status == "empty":
					save_requested.emit(slot.slot)
				else:
					_confirm_save(slot.slot)
			else:
				_request_load(slot.slot))
		var delete: Button = row.get_node("Delete")
		delete.text = "×"
		delete.tooltip_text = "Eliminar slot %s" % slot.slot
		delete.visible = slot.status != "empty"
		delete.pressed.connect(func(): _confirm_delete(slot.slot))
	_connect_button("Back", show_pause if origin == "pause" else show_main)

func _confirm_delete(slot: int) -> void:
	_confirmation_return_screen = "slots"
	_confirmation("Eliminar partida", "¿Eliminar el slot %s? Esta operación no se puede deshacer." % slot, "Eliminar", func(): delete_requested.emit(slot), func(): show_slots(slot_mode, origin, _slots), origin == "main")

func _confirm_save(slot: int) -> void:
	_confirmation_return_screen = "slots"
	_confirmation("Reemplazar partida", "¿Reemplazar el guardado del slot %s?" % slot, "Guardar", func(): save_requested.emit(slot), func(): show_slots(slot_mode, origin, _slots), false)

func _request_load(slot: int) -> void:
	if origin != "pause" or not has_unsaved_changes:
		load_requested.emit(slot)
		return
	_confirmation_return_screen = "slots"
	_confirmation("Cargar partida", "Los cambios sin guardar se perderán.", "Cargar", func(): load_requested.emit(slot), func(): show_slots(slot_mode, origin, _slots), false)

func show_message(message: String) -> void:
	screen = "message"
	_clear("Tribes Revival", origin == "main")
	_content.find_child("Message").text = message
	_connect_button("Back", func(): show_slots(slot_mode, origin, _slots))

func handle_escape() -> void:
	match screen:
		"pause": resume_requested.emit()
		"tutorial": show_main()
		"confirmation":
			if _confirmation_return_screen == "slots":
				show_slots(slot_mode, origin, _slots)
			else:
				show_pause()
		"message": show_slots(slot_mode, origin, _slots)
		"slots":
			if origin == "pause":
				show_pause()
			else:
				show_main()
