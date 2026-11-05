class_name TribeSaveRepository
extends RefCounted
## Three local JSON slots. UI owns confirmation; repository touches one slot only.

const State = preload("res://scripts/simulation/game_state.gd")
const SLOT_COUNT := 3
const SCHEMA_VERSION := 1
var _directory: String
var _template: Dictionary

func _init(directory: String = "user://saves") -> void:
	_directory = directory
	_template = State.create_initial()
	# Resource yield and unit navigation are optional in the current schema.
	_template.resources[0].erase("yieldAmount")

static func normalized_state(state: Dictionary) -> Dictionary:
	var normalized := state.duplicate(true)
	normalized.phase = "playing"
	return normalized

static func fingerprint(state: Dictionary) -> String:
	return JSON.stringify(normalized_state(state), "", true, true)

func list_slots() -> Array:
	var slots: Array = []
	for slot in range(1, SLOT_COUNT + 1):
		slots.append(read_slot(slot))
	return slots

func _path(slot: int) -> String:
	return _directory.path_join("tribes-revival.save.v1.slot.%s.json" % slot)

func read_slot(slot: int) -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT:
		return {"slot": slot, "status": "invalid", "reason": "incompatible"}
	var path := _path(slot)
	# Recover the previous completed write if interrupted during replacement.
	if not FileAccess.file_exists(path) and FileAccess.file_exists(path + ".bak"):
		DirAccess.rename_absolute(path + ".bak", path)
	if not FileAccess.file_exists(path):
		return {"slot": slot, "status": "empty"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"slot": slot, "status": "invalid", "reason": "corrupt"}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {"slot": slot, "status": "invalid", "reason": "corrupt"}
	if parsed.get("schemaVersion") != SCHEMA_VERSION or not parsed.get("gameState") is Dictionary or parsed.gameState.get("version") != 17:
		return {"slot": slot, "status": "invalid", "reason": "incompatible"}
	if not _matches(parsed.gameState, _template) or not _matches(parsed.get("metadata"), {"savedAt": "", "level": 0, "minionCount": 0}):
		return {"slot": slot, "status": "invalid", "reason": "corrupt"}
	return {"slot": slot, "status": "valid", "save": parsed}

func save_slot(slot: int, state: Dictionary, saved_at: String = "") -> Dictionary:
	if slot < 1 or slot > SLOT_COUNT:
		return {"ok": false, "error": "Slot no válido"}
	if saved_at.is_empty():
		saved_at = Time.get_datetime_string_from_system(true) + "Z"
	var normalized := normalized_state(state)
	var envelope := {"schemaVersion": SCHEMA_VERSION, "metadata": {"savedAt": saved_at, "level": normalized.progression.level, "minionCount": normalized.units.size()}, "gameState": normalized}
	var error := DirAccess.make_dir_recursive_absolute(_directory)
	if error != OK:
		return {"ok": false, "error": "No se pudo crear la carpeta de guardados"}
	var path := _path(slot)
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "No se pudo escribir el guardado"}
	file.store_string(JSON.stringify(envelope, "", false, true))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return {"ok": false, "error": "La escritura del guardado falló"}
	var backup := path + ".bak"
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	if FileAccess.file_exists(path):
		error = DirAccess.rename_absolute(path, backup)
		if error != OK:
			DirAccess.remove_absolute(temporary)
			return {"ok": false, "error": "No se pudo reemplazar el guardado anterior"}
	error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, path)
		DirAccess.remove_absolute(temporary)
		return {"ok": false, "error": "No se pudo finalizar el guardado"}
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	return {"ok": true, "save": envelope}

func delete_slot(slot: int) -> Error:
	if slot < 1 or slot > SLOT_COUNT:
		return ERR_INVALID_PARAMETER
	var path := _path(slot)
	# A backup of the same slot must not resurrect a confirmed deletion.
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			var error := DirAccess.remove_absolute(path + suffix)
			if error != OK:
				return error
	return OK

func _matches(value: Variant, template: Variant) -> bool:
	if template == null:
		return value == null or value is String or (value is Dictionary and _matches(value, {"x": 0.0, "y": 0.0}))
	if template is Dictionary:
		if not value is Dictionary:
			return false
		for key in template:
			if not value.has(key) or not _matches(value[key], template[key]):
				return false
		return true
	if template is Array:
		if not value is Array:
			return false
		if not template.is_empty():
			for entry in value:
				if not _matches(entry, template[0]):
					return false
		return true
	if template is int or template is float:
		return (value is int or value is float) and is_finite(float(value))
	return typeof(value) == typeof(template)
